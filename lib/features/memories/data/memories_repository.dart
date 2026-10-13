import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/memory_model.dart';

class MemoriesRepository {
  final FirebaseFirestore? _customFirestore;

  MemoriesRepository({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  Stream<List<MemoryModel>> watchMemories(String coupleId) {
    return _firestore
        .collection('coupleSpaces')
        .doc(coupleId)
        .collection('memories')
        .orderBy('memoryDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => MemoryModel.fromFirestore(doc)).toList();
    }).handleError((error) {
      return <MemoryModel>[];
    });
  }

  Future<void> createMemory({
    required String coupleId,
    required String title,
    String? description,
    String? mediaUrl,
    required DateTime memoryDate,
    required String createdBy,
  }) async {
    final ref = _firestore
        .collection('coupleSpaces')
        .doc(coupleId)
        .collection('memories')
        .doc();

    final memory = MemoryModel(
      id: ref.id,
      title: title.trim(),
      description: description?.trim(),
      mediaUrl: mediaUrl,
      memoryDate: memoryDate,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );

    await ref.set(memory.toFirestore());
  }

  Future<void> deleteMemory(String coupleId, String memoryId) async {
    await _firestore
        .collection('coupleSpaces')
        .doc(coupleId)
        .collection('memories')
        .doc(memoryId)
        .delete();
  }
}
