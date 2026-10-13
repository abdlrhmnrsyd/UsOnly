import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/message_model.dart';

class ChatRepository {
  final FirebaseFirestore? _customFirestore;

  ChatRepository({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  Stream<List<MessageModel>> watchMessages(String conversationId, {int limit = 50}) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList();
    }).handleError((error) {
      return <MessageModel>[];
    });
  }

  Future<void> sendTextMessage({
    required String conversationId,
    required String senderUid,
    required String text,
  }) async {
    final convRef = _firestore.collection('conversations').doc(conversationId);
    final msgRef = convRef.collection('messages').doc();

    final now = DateTime.now();
    final message = MessageModel(
      id: msgRef.id,
      senderUid: senderUid,
      type: 'text',
      text: text.trim(),
      createdAt: now,
      readBy: [senderUid],
    );

    final batch = _firestore.batch();
    batch.set(msgRef, message.toFirestore());
    batch.set(
      convRef,
      {
        'conversationId': conversationId,
        'lastMessage': text.trim(),
        'lastMessageAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> sendImageMessage({
    required String conversationId,
    required String senderUid,
    required String mediaUrl,
    String? caption,
  }) async {
    final convRef = _firestore.collection('conversations').doc(conversationId);
    final msgRef = convRef.collection('messages').doc();

    final now = DateTime.now();
    final message = MessageModel(
      id: msgRef.id,
      senderUid: senderUid,
      type: 'image',
      mediaUrl: mediaUrl,
      caption: caption?.trim(),
      createdAt: now,
      readBy: [senderUid],
    );

    final batch = _firestore.batch();
    batch.set(msgRef, message.toFirestore());
    batch.set(
      convRef,
      {
        'conversationId': conversationId,
        'lastMessage': caption?.isNotEmpty == true ? caption : '[Foto]',
        'lastMessageAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> sendPapMessage({
    required String conversationId,
    required String senderUid,
    required String mediaUrl,
    String? caption,
  }) async {
    final convRef = _firestore.collection('conversations').doc(conversationId);
    final msgRef = convRef.collection('messages').doc();

    final now = DateTime.now();
    final message = MessageModel(
      id: msgRef.id,
      senderUid: senderUid,
      type: 'pap',
      mediaUrl: mediaUrl,
      caption: caption?.trim(),
      createdAt: now,
      readBy: [senderUid],
    );

    final batch = _firestore.batch();
    batch.set(msgRef, message.toFirestore());
    batch.set(
      convRef,
      {
        'conversationId': conversationId,
        'lastMessage': caption?.isNotEmpty == true ? '📸 PAP: $caption' : '📸 Mengirim PAP baru',
        'lastMessageAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> sendLocationMessage({
    required String conversationId,
    required String senderUid,
    required double latitude,
    required double longitude,
    String? placeLabel,
  }) async {
    final convRef = _firestore.collection('conversations').doc(conversationId);
    final msgRef = convRef.collection('messages').doc();

    final now = DateTime.now();
    final message = MessageModel(
      id: msgRef.id,
      senderUid: senderUid,
      type: 'location',
      latitude: latitude,
      longitude: longitude,
      placeLabel: placeLabel,
      createdAt: now,
      readBy: [senderUid],
    );

    final batch = _firestore.batch();
    batch.set(msgRef, message.toFirestore());
    batch.set(
      convRef,
      {
        'conversationId': conversationId,
        'lastMessage': '📍 Berbagi lokasi: ${placeLabel ?? 'Lokasi saat ini'}',
        'lastMessageAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> markRead({
    required String conversationId,
    required String messageId,
    required String readerUid,
  }) async {
    final msgRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);

    await msgRef.update({
      'readBy': FieldValue.arrayUnion([readerUid]),
    });
  }

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }
}
