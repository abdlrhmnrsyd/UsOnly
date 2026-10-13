import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/user_model.dart';

class AuthRepository {
  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _customAuth = auth,
        _customFirestore = firestore;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  Stream<UserModel?> watchUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    }).handleError((error) {
      return null;
    });
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth
        .createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        )
        .timeout(const Duration(seconds: 45));

    final user = credential.user!;
    try {
      await user.updateDisplayName(displayName.trim()).timeout(const Duration(seconds: 8));
    } catch (_) {}

    final now = DateTime.now();
    final profile = UserModel(
      uid: user.uid,
      email: email.trim(),
      displayName: displayName.trim(),
      createdAt: now,
      updatedAt: now,
    );

    // Save Firestore profile with timeout & non-blocking fallback
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(profile.toFirestore())
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Even if Firestore write is delayed, auth user was created successfully
    }
    return profile;
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth
        .signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        )
        .timeout(const Duration(seconds: 45));

    final user = credential.user!;
    UserModel? profile;
    try {
      profile = await getUserProfile(user.uid).timeout(const Duration(seconds: 15));
    } catch (_) {}

    // Auto-create Firestore document if not present
    if (profile == null) {
      profile = UserModel(
        uid: user.uid,
        email: user.email ?? email,
        displayName: user.displayName ?? 'User',
      );
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(profile.toFirestore())
            .timeout(const Duration(seconds: 15));
      } catch (_) {}
    }

    return profile;
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (displayName != null) {
      updates['displayName'] = displayName.trim();
      await _auth.currentUser?.updateDisplayName(displayName.trim());
    }
    if (photoUrl != null) {
      updates['photoUrl'] = photoUrl;
      await _auth.currentUser?.updatePhotoURL(photoUrl);
    }

    await _firestore.collection('users').doc(uid).update(updates);
  }

  Future<void> updateCoupleId(String coupleId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set({
      'coupleId': coupleId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Delete Firestore profile
    await _firestore.collection('users').doc(user.uid).delete();
    // Delete Firebase Auth identity
    await user.delete();
  }
}
