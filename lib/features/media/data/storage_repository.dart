import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

class StorageRepository {
  final FirebaseFirestore? _customFirestore;

  StorageRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// Compresses an image file and converts it into an optimized Base64 Data URL.
  /// Typically compresses to 30KB - 70KB, well within Firestore 1MB limits.
  Future<String> _compressAndEncode(
    File file, {
    int maxDimension = 800,
    int quality = 70,
    Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.2);
    final bytes = await file.readAsBytes();
    onProgress?.call(0.4);

    final image = img.decodeImage(bytes);
    if (image == null) {
      // Fallback if image cannot be decoded
      final rawBase64 = base64Encode(bytes);
      onProgress?.call(1.0);
      return 'data:image/jpeg;base64,$rawBase64';
    }

    onProgress?.call(0.6);
    img.Image resized = image;
    if (image.width > maxDimension || image.height > maxDimension) {
      if (image.width >= image.height) {
        resized = img.copyResize(image, width: maxDimension);
      } else {
        resized = img.copyResize(image, height: maxDimension);
      }
    }

    onProgress?.call(0.8);
    final jpgBytes = img.encodeJpg(resized, quality: quality);
    final base64String = base64Encode(jpgBytes);
    onProgress?.call(1.0);

    return 'data:image/jpeg;base64,$base64String';
  }

  /// Stores couple photo in Firestore (coupleSpaces/{coupleId}/media)
  /// without using Firebase Storage buckets.
  Future<String> uploadCouplePhoto({
    required String coupleId,
    required File file,
    String? caption,
    String type = 'photo',
    Function(double progress)? onProgress,
  }) async {
    final dataUrl = await _compressAndEncode(
      file,
      onProgress: onProgress,
    );

    final mediaRef = _firestore
        .collection('coupleSpaces')
        .doc(coupleId)
        .collection('media')
        .doc();

    await mediaRef.set({
      'id': mediaRef.id,
      'coupleId': coupleId,
      'dataUrl': dataUrl,
      'type': type,
      'caption': caption,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return dataUrl;
  }

  /// Stores profile avatar directly in Firestore without Firebase Storage.
  Future<String> uploadProfilePhoto({
    required String uid,
    required File file,
  }) async {
    final dataUrl = await _compressAndEncode(
      file,
      maxDimension: 500,
      quality: 68,
    );

    // Save avatar in Firestore user doc or subcollection
    await _firestore.collection('users').doc(uid).set({
      'photoUrl': dataUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return dataUrl;
  }
}
