import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class PairingRepository {
  final FirebaseFirestore? _customFirestore;
  final FirebaseFunctions? _customFunctions;

  static const String _chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  PairingRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _customFirestore = firestore,
        _customFunctions = functions;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions => _customFunctions ?? FirebaseFunctions.instance;

  String _generateRawCode(int length) {
    final rand = Random.secure();
    return List.generate(length, (_) => _chars[rand.nextInt(_chars.length)]).join();
  }

  String hashPairingCode(String code) {
    final clean = code.trim().replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    final bytes = utf8.encode(clean);
    return sha256.convert(bytes).toString();
  }

  Future<Map<String, dynamic>> createPairingCode({
    required String creatorUid,
  }) async {
    // 1. Try Cloud Function first if available, with a fast 3-second timeout
    try {
      final callable = _functions.httpsCallable('createPairingCode');
      final result = await callable.call().timeout(const Duration(seconds: 3));
      return Map<String, dynamic>.from(result.data as Map);
    } catch (_) {
      // 2. Atomic fallback via Firestore transaction
      return await _createPairingCodeFirestore(creatorUid);
    }
  }

  Future<Map<String, dynamic>> _createPairingCodeFirestore(String creatorUid) async {
    final rawCode = _generateRawCode(6);
    final codeHash = hashPairingCode(rawCode);

    final coupleRef = _firestore.collection('coupleSpaces').doc();
    final coupleId = coupleRef.id;

    final codeRef = _firestore.collection('pairingCodes').doc(codeHash);

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 10));

    await _firestore.runTransaction((transaction) async {
      // Create pending couple space
      transaction.set(coupleRef, {
        'coupleId': coupleId,
        'memberUids': [creatorUid],
        'status': 'pending',
        'createdBy': creatorUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'pairedAt': null,
      });

      // Create single-use expiring pairing code
      transaction.set(codeRef, {
        'codeHash': codeHash,
        'coupleId': coupleId,
        'createdBy': creatorUid,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'usedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return {
      'code': rawCode,
      'coupleId': coupleId,
      'expiresAt': expiresAt.toIso8601String(),
      'expiresInSeconds': 600,
    };
  }

  Future<Map<String, dynamic>> redeemPairingCode({
    required String joiningUid,
    required String rawCode,
  }) async {
    // 1. Try Cloud Function first with 3-second timeout
    try {
      final callable = _functions.httpsCallable('redeemPairingCode');
      final result = await callable.call({'code': rawCode.trim().toUpperCase()}).timeout(const Duration(seconds: 3));
      return Map<String, dynamic>.from(result.data as Map);
    } catch (_) {
      // 2. Atomic conflict-safe transaction fallback
      return await _redeemPairingCodeFirestore(joiningUid, rawCode);
    }
  }

  Future<Map<String, dynamic>> _redeemPairingCodeFirestore(
    String joiningUid,
    String rawCode,
  ) async {
    final cleanCode = rawCode.trim().replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    final codeHash = hashPairingCode(cleanCode);
    final codeRef = _firestore.collection('pairingCodes').doc(codeHash);

    final result = await _firestore.runTransaction((transaction) async {
      // 1. Read code
      final codeSnap = await transaction.get(codeRef);
      if (!codeSnap.exists) {
        throw Exception('Kode koneksi tidak valid atau tidak ditemukan.');
      }

      final codeData = codeSnap.data()!;
      if (codeData['usedAt'] != null) {
        throw Exception('Kode koneksi ini sudah pernah digunakan.');
      }

      final expiresAt = (codeData['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception('Kode koneksi telah kedaluwarsa.');
      }

      final creatorUid = codeData['createdBy'] as String;
      String partnerUid = creatorUid;

      // Allow self-pairing in debug/emulator mode to facilitate single-device testing
      if (creatorUid == joiningUid) {
        if (kDebugMode) {
          final suffix = creatorUid.length > 5 ? creatorUid.substring(0, 5) : creatorUid;
          partnerUid = 'partner_demo_$suffix';
        } else {
          throw Exception('Anda tidak dapat menggunakan kode koneksi buatan sendiri.');
        }
      }

      final coupleId = codeData['coupleId'] as String;
      final coupleRef = _firestore.collection('coupleSpaces').doc(coupleId);

      // 2. Read couple space
      final coupleSnap = await transaction.get(coupleRef);
      if (!coupleSnap.exists) {
        throw Exception('Ruang pasangan tidak ditemukan.');
      }

      final coupleData = coupleSnap.data()!;
      final status = coupleData['status'] as String? ?? 'pending';
      if (status != 'pending' && status != 'active') {
        throw Exception('Ruang pasangan ini sudah tidak menerima anggota baru.');
      }

      // 3. Read joining user
      final userRef = _firestore.collection('users').doc(joiningUid);
      final userSnap = await transaction.get(userRef);
      if (userSnap.exists && (userSnap.data()?['coupleId'] != null) && (userSnap.data()?['coupleId'] != coupleId)) {
        throw Exception('Anda sudah terhubung ke ruang pasangan lain.');
      }

      // 4. Atomic writes
      // Mark code as used
      transaction.update(codeRef, {'usedAt': FieldValue.serverTimestamp()});

      // Update couple space to active with exactly 2 members
      final finalPartner = partnerUid == creatorUid ? joiningUid : partnerUid;
      transaction.set(coupleRef, {
        'coupleId': coupleId,
        'memberUids': [creatorUid, finalPartner],
        'status': 'active',
        'pairedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update joining user's coupleId (always allowed by rules since it's the current user)
      transaction.set(userRef, {
        'coupleId': coupleId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return {
        'coupleId': coupleId,
        'partnerUid': partnerUid,
        'creatorUid': creatorUid,
        'finalPartner': finalPartner,
      };
    });

    // Secondary non-blocking writes outside transaction
    final coupleId = result['coupleId'] as String;
    final creatorUid = result['creatorUid'] as String;
    final partnerUid = result['partnerUid'] as String;
    final finalPartner = result['finalPartner'] as String;

    try {
      final creatorDocRef = _firestore.collection('users').doc(creatorUid);
      await creatorDocRef.set({
        'coupleId': coupleId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    if (partnerUid != creatorUid && partnerUid != joiningUid) {
      try {
        final demoPartnerRef = _firestore.collection('users').doc(partnerUid);
        await demoPartnerRef.set({
          'uid': partnerUid,
          'displayName': 'My Love ❤️',
          'email': 'partner@usonly.app',
          'coupleId': coupleId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    try {
      final convRef = _firestore.collection('conversations').doc('conv_$coupleId');
      await convRef.set({
        'conversationId': 'conv_$coupleId',
        'coupleId': coupleId,
        'memberUids': [creatorUid, finalPartner],
        'lastMessage': 'Welcome to UsOnly! 💕',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    return {
      'coupleId': coupleId,
      'partnerUid': partnerUid,
    };
  }

  /// Simulate partner connecting to couple space (useful for emulator testing)
  Future<void> simulatePartnerConnection({
    required String coupleId,
    required String creatorUid,
  }) async {
    final suffix = creatorUid.length > 5 ? creatorUid.substring(0, 5) : creatorUid;
    final partnerUid = 'partner_demo_$suffix';

    final coupleRef = _firestore.collection('coupleSpaces').doc(coupleId);
    await coupleRef.set({
      'coupleId': coupleId,
      'memberUids': [creatorUid, partnerUid],
      'status': 'active',
      'pairedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final userRef = _firestore.collection('users').doc(creatorUid);
    await userRef.set({
      'coupleId': coupleId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      final partnerRef = _firestore.collection('users').doc(partnerUid);
      await partnerRef.set({
        'uid': partnerUid,
        'displayName': 'My Love ❤️',
        'email': 'partner@usonly.app',
        'coupleId': coupleId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    try {
      final convRef = _firestore.collection('conversations').doc('conv_$coupleId');
      await convRef.set({
        'conversationId': 'conv_$coupleId',
        'coupleId': coupleId,
        'memberUids': [creatorUid, partnerUid],
        'lastMessage': 'Connected in UsOnly! 💕',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCoupleSpace(String coupleId) {
    return _firestore.collection('coupleSpaces').doc(coupleId).snapshots();
  }
}
