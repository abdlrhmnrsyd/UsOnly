import 'package:cloud_firestore/cloud_firestore.dart';

class MemoryModel {
  final String id;
  final String title;
  final String? description;
  final String? mediaUrl;
  final DateTime memoryDate;
  final String createdBy;
  final DateTime createdAt;

  const MemoryModel({
    required this.id,
    required this.title,
    this.description,
    this.mediaUrl,
    required this.memoryDate,
    required this.createdBy,
    required this.createdAt,
  });

  factory MemoryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return MemoryModel(
      id: snapshot.id,
      title: data['title'] as String? ?? 'Our Memory',
      description: data['description'] as String?,
      mediaUrl: data['mediaUrl'] as String?,
      memoryDate: (data['memoryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'mediaUrl': mediaUrl,
      'memoryDate': Timestamp.fromDate(memoryDate),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
