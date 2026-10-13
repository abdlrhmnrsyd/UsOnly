import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

admin.initializeApp();
const db = admin.firestore();

const CODE_CHARS = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";

function generateSecureCode(length = 6): string {
  const bytes = crypto.randomBytes(length);
  let code = "";
  for (let i = 0; i < length; i++) {
    code += CODE_CHARS[bytes[i] % CODE_CHARS.length];
  }
  return code;
}

function hashCode(code: string): string {
  return crypto.createHash("sha256").update(code.trim().toUpperCase()).digest("hex");
}

/**
 * 1. createPairingCode:
 * Generates an expiring (10-minute), cryptographically secure pairing code
 * and pending couple space for the authenticated user.
 */
export const createPairingCode = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required to create a pairing code.");
  }

  const creatorUid = request.auth.uid;

  // Check if user is already paired
  const userDoc = await db.collection("users").doc(creatorUid).get();
  if (userDoc.exists && userDoc.data()?.coupleId) {
    throw new HttpsError("failed-precondition", "You already belong to an active couple space.");
  }

  const rawCode = generateSecureCode(6);
  const codeHash = hashCode(rawCode);

  const coupleRef = db.collection("coupleSpaces").doc();
  const coupleId = coupleRef.id;
  const codeRef = db.collection("pairingCodes").doc(codeHash);

  const now = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + 10 * 60 * 1000); // 10 minutes

  await db.runTransaction(async (transaction) => {
    transaction.set(coupleRef, {
      coupleId: coupleId,
      memberUids: [creatorUid],
      status: "pending",
      createdBy: creatorUid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      pairedAt: null,
    });

    transaction.set(codeRef, {
      codeHash: codeHash,
      coupleId: coupleId,
      createdBy: creatorUid,
      expiresAt: expiresAt,
      usedAt: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return {
    code: rawCode,
    coupleId: coupleId,
    expiresAt: expiresAt.toDate().toISOString(),
    expiresInSeconds: 600,
  };
});

/**
 * 2. redeemPairingCode:
 * Atomically validates, consumes code, and links partner to the couple space.
 */
export const redeemPairingCode = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required to redeem a pairing code.");
  }

  const joiningUid = request.auth.uid;
  const rawCode = request.data.code as string;

  if (!rawCode || rawCode.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Connection code is required.");
  }

  const codeHash = hashCode(rawCode);
  const codeRef = db.collection("pairingCodes").doc(codeHash);

  return await db.runTransaction(async (transaction) => {
    const codeSnap = await transaction.get(codeRef);
    if (!codeSnap.exists) {
      throw new HttpsError("not-found", "Invalid connection code.");
    }

    const codeData = codeSnap.data()!;
    if (codeData.usedAt) {
      throw new HttpsError("already-exists", "This connection code has already been used.");
    }

    const expiresAt = codeData.expiresAt.toDate();
    if (new Date() > expiresAt) {
      throw new HttpsError("deadline-exceeded", "This connection code has expired.");
    }

    const creatorUid = codeData.createdBy as string;
    if (creatorUid === joiningUid) {
      throw new HttpsError("invalid-argument", "You cannot redeem your own connection code.");
    }

    const coupleId = codeData.coupleId as string;
    const coupleRef = db.collection("coupleSpaces").doc(coupleId);
    const coupleSnap = await transaction.get(coupleRef);

    if (!coupleSnap.exists) {
      throw new HttpsError("not-found", "The couple space could not be found.");
    }

    const coupleData = coupleSnap.data()!;
    const members = (coupleData.memberUids || []) as string[];
    if (coupleData.status !== "pending" || members.length >= 2) {
      throw new HttpsError("failed-precondition", "This couple space is already full.");
    }

    // Verify joining user isn't already paired
    const userRef = db.collection("users").doc(joiningUid);
    const userSnap = await transaction.get(userRef);
    if (userSnap.exists && userSnap.data()?.coupleId) {
      throw new HttpsError("failed-precondition", "You already belong to an active couple space.");
    }

    // Atomic updates
    transaction.update(codeRef, {
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.update(coupleRef, {
      memberUids: [creatorUid, joiningUid],
      status: "active",
      pairedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.update(db.collection("users").doc(creatorUid), {
      coupleId: coupleId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.update(userRef, {
      coupleId: coupleId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Create canonical conversation
    const convRef = db.collection("conversations").doc(`conv_${coupleId}`);
    transaction.set(convRef, {
      conversationId: `conv_${coupleId}`,
      coupleId: coupleId,
      memberUids: [creatorUid, joiningUid],
      lastMessage: null,
      lastMessageAt: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      coupleId: coupleId,
      partnerUid: creatorUid,
    };
  });
});

/**
 * 3. onMessageCreatedSendNotification:
 * Sends privacy-conscious FCM push notification to partner when a new message arrives.
 */
export const onMessageCreatedSendNotification = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const messageData = snapshot.data();
    const senderUid = messageData.senderUid as string;
    const conversationId = event.params.conversationId;

    // Fetch conversation to find partner UID
    const convDoc = await db.collection("conversations").doc(conversationId).get();
    if (!convDoc.exists) return;

    const memberUids = (convDoc.data()?.memberUids || []) as string[];
    const partnerUid = memberUids.find((id) => id !== senderUid);
    if (!partnerUid) return;

    // Fetch sender profile for display name
    const senderDoc = await db.collection("users").doc(senderUid).get();
    const senderName = senderDoc.data()?.displayName || "Your partner";

    // Fetch partner device tokens
    const tokensSnap = await db.collection("users").doc(partnerUid).collection("deviceTokens").get();
    if (tokensSnap.empty) return;

    const tokens = tokensSnap.docs.map((doc) => doc.data().token as string).filter(Boolean);
    if (tokens.length === 0) return;

    const notificationBody = messageData.type === "image"
      ? "Sent a photo"
      : (messageData.text || "New message");

    const payload: admin.messaging.MulticastMessage = {
      tokens: tokens,
      notification: {
        title: senderName,
        body: notificationBody,
      },
      data: {
        conversationId: conversationId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    const response = await admin.messaging().sendEachForMulticast(payload);

    // Clean up expired or invalid device tokens
    const cleanupPromises: Promise<FirebaseFirestore.WriteResult>[] = [];
    response.responses.forEach((res, index) => {
      if (!res.success && res.error) {
        const errCode = res.error.code;
        if (
          errCode === "messaging/invalid-registration-token" ||
          errCode === "messaging/registration-token-not-registered"
        ) {
          const docId = tokensSnap.docs[index].id;
          cleanupPromises.push(
            db.collection("users").doc(partnerUid).collection("deviceTokens").doc(docId).delete()
          );
        }
      }
    });

    await Promise.all(cleanupPromises);
  }
);
