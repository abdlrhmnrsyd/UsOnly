import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderUid;
  final String type; // 'text', 'image', 'pap', 'location'
  final String? text;
  final String? mediaId;
  final String? mediaUrl;
  final String? caption;
  final double? latitude;
  final double? longitude;
  final String? placeLabel;
  final DateTime createdAt;
  final List<String> readBy;

  const MessageModel({
    required this.id,
    required this.senderUid,
    required this.type,
    this.text,
    this.mediaId,
    this.mediaUrl,
    this.caption,
    this.latitude,
    this.longitude,
    this.placeLabel,
    required this.createdAt,
    this.readBy = const [],
  });

  bool isReadBy(String uid) => readBy.contains(uid);

  factory MessageModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return MessageModel(
      id: snapshot.id,
      senderUid: data['senderUid'] as String? ?? '',
      type: data['type'] as String? ?? 'text',
      text: data['text'] as String?,
      mediaId: data['mediaId'] as String?,
      mediaUrl: data['mediaUrl'] as String?,
      caption: data['caption'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      placeLabel: data['placeLabel'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: List<String>.from(data['readBy'] as List? ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderUid': senderUid,
      'type': type,
      'text': text,
      'mediaId': mediaId,
      'mediaUrl': mediaUrl,
      'caption': caption,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (placeLabel != null) 'placeLabel': placeLabel,
      'createdAt': Timestamp.fromDate(createdAt),
      'readBy': readBy,
    };
  }
}
