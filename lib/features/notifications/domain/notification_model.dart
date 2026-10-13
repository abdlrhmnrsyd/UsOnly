import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String coupleId;
  final String senderUid;
  final String senderName;
  final String title;
  final String body;
  final String type; // 'chat', 'pap', 'location', 'miss_you', 'ping'
  final DateTime createdAt;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.coupleId,
    required this.senderUid,
    required this.senderName,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return NotificationModel(
      id: snapshot.id,
      coupleId: data['coupleId'] as String? ?? '',
      senderUid: data['senderUid'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Partner',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'chat',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'coupleId': coupleId,
      'senderUid': senderUid,
      'senderName': senderName,
      'title': title,
      'body': body,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }
}
