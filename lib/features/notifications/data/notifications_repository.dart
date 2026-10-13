import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/notification_model.dart';

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) => NotificationsRepository());

class NotificationsRepository {
  final FirebaseFirestore? _customFirestore;

  NotificationsRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  Stream<List<NotificationModel>> watchNotifications(String coupleId) {
    return _firestore
        .collection('coupleSpaces')
        .doc(coupleId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
    }).handleError((error) {
      return <NotificationModel>[];
    });
  }

  Future<void> sendNotification({
    required String coupleId,
    required String senderUid,
    required String senderName,
    required String title,
    required String body,
    required String type,
  }) async {
    final docRef = _firestore
        .collection('coupleSpaces')
        .doc(coupleId)
        .collection('notifications')
        .doc();

    final notif = NotificationModel(
      id: docRef.id,
      coupleId: coupleId,
      senderUid: senderUid,
      senderName: senderName,
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await docRef.set(notif.toFirestore());
  }

  Future<void> markAsRead(String coupleId, String notifId) async {
    await _firestore
        .collection('coupleSpaces')
        .doc(coupleId)
        .collection('notifications')
        .doc(notifId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead(String coupleId, String recipientUid) async {
    final snap = await _firestore
        .collection('coupleSpaces')
        .doc(coupleId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in snap.docs) {
      if (doc.data()['senderUid'] != recipientUid) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }
}
