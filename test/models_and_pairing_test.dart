import 'package:flutter_test/flutter_test.dart';
import 'package:usonly/features/auth/domain/user_model.dart';
import 'package:usonly/features/chat/domain/message_model.dart';
import 'package:usonly/features/memories/domain/memory_model.dart';
import 'package:usonly/features/notifications/domain/notification_model.dart';
import 'package:usonly/features/pairing/data/pairing_repository.dart';
import 'package:usonly/features/tracking/domain/location_model.dart';

void main() {
  group('UserModel Unit Tests', () {
    test('UserModel instantiation and isPaired status', () {
      const unpairedUser = UserModel(
        uid: 'user_123',
        email: 'test@usonly.app',
        displayName: 'Alex',
        coupleId: null,
      );

      expect(unpairedUser.isPaired, false);

      final pairedUser = unpairedUser.copyWith(coupleId: 'couple_abc');
      expect(pairedUser.isPaired, true);
      expect(pairedUser.coupleId, 'couple_abc');
      expect(pairedUser.displayName, 'Alex');
    });

    test('UserModel toFirestore generates correct map keys', () {
      final now = DateTime(2025, 1, 1);
      final user = UserModel(
        uid: 'user_456',
        email: 'partner@usonly.app',
        displayName: 'Jordan',
        coupleId: 'couple_xyz',
        createdAt: now,
      );

      final map = user.toFirestore();
      expect(map['uid'], 'user_456');
      expect(map['email'], 'partner@usonly.app');
      expect(map['displayName'], 'Jordan');
      expect(map['coupleId'], 'couple_xyz');
    });
  });

  group('MessageModel Unit Tests', () {
    test('MessageModel isReadBy correctly identifies read receipts', () {
      final msg = MessageModel(
        id: 'msg_001',
        senderUid: 'user_1',
        type: 'text',
        text: 'just us, always.',
        createdAt: DateTime.now(),
        readBy: ['user_1', 'user_2'],
      );

      expect(msg.isReadBy('user_1'), true);
      expect(msg.isReadBy('user_2'), true);
      expect(msg.isReadBy('user_3'), false);
    });

    test('MessageModel toFirestore serialization', () {
      final now = DateTime(2025, 2, 14, 18, 0, 0);
      final msg = MessageModel(
        id: 'msg_002',
        senderUid: 'user_1',
        type: 'image',
        mediaUrl: 'https://storage.googleapis.com/test.jpg',
        caption: 'Our anniversary dinner',
        createdAt: now,
        readBy: ['user_1'],
      );

      final map = msg.toFirestore();
      expect(map['type'], 'image');
      expect(map['mediaUrl'], 'https://storage.googleapis.com/test.jpg');
      expect(map['caption'], 'Our anniversary dinner');
      expect(map['readBy'], ['user_1']);
    });
  });

  group('MemoryModel Unit Tests', () {
    test('MemoryModel serialization round-trip', () {
      final memoryDate = DateTime(2024, 6, 1);
      final createdDate = DateTime(2024, 6, 2);

      final memory = MemoryModel(
        id: 'mem_001',
        title: 'Trip to Kyoto',
        description: 'Walking under the torii gates together',
        mediaUrl: 'https://storage.googleapis.com/memories/kyoto.jpg',
        memoryDate: memoryDate,
        createdBy: 'user_1',
        createdAt: createdDate,
      );

      final map = memory.toFirestore();
      expect(map['title'], 'Trip to Kyoto');
      expect(map['description'], 'Walking under the torii gates together');
      expect(map['createdBy'], 'user_1');
    });
  });

  group('Pairing System Unit Tests', () {
    test('PairingRepository SHA-256 code hashing is deterministic and case-insensitive', () {
      final repo = PairingRepository();

      final hashLower = repo.hashPairingCode('ab12cd');
      final hashUpper = repo.hashPairingCode('AB12CD');
      final hashSpaced = repo.hashPairingCode('  AB12CD  ');

      expect(hashLower, hashUpper);
      expect(hashUpper, hashSpaced);
      expect(hashUpper.length, 64); // SHA-256 hex string length
    });

    test('Different codes produce distinct hashes', () {
      final repo = PairingRepository();

      final hash1 = repo.hashPairingCode('CODE01');
      final hash2 = repo.hashPairingCode('CODE02');

      expect(hash1, isNot(equals(hash2)));
    });

    test('Codes with hyphens and spaces normalize to the same hash', () {
      final repo = PairingRepository();

      final hashStandard = repo.hashPairingCode('ABCDEF');
      final hashHyphenated = repo.hashPairingCode('ABC-DEF');
      final hashSpaces = repo.hashPairingCode('A B C D E F');

      expect(hashHyphenated, hashStandard);
      expect(hashSpaces, hashStandard);
    });
  });

  group('LocationModel & Tracking Tests', () {
    test('LocationModel calculates distance and formatted text correctly', () {
      final loc1 = LocationModel(
        uid: 'user_1',
        displayName: 'Kamu',
        latitude: -6.2000,
        longitude: 106.8166,
        placeLabel: 'Di Rumah 🏡',
        batteryLevel: 90,
        updatedAt: DateTime.now(),
      );

      final loc2 = LocationModel(
        uid: 'user_2',
        displayName: 'Doi',
        latitude: -6.2100, // approx 1.1 km away
        longitude: 106.8166,
        placeLabel: 'Di Kantor 🏢',
        batteryLevel: 75,
        updatedAt: DateTime.now(),
      );

      final distance = loc1.distanceTo(loc2);
      expect(distance, greaterThan(1000));
      expect(distance, lessThan(1500));

      final formatted = loc1.formattedDistanceTo(loc2);
      expect(formatted.contains('km'), true);

      // Close together test (< 50m)
      final locClose = loc1;
      expect(loc1.formattedDistanceTo(locClose), 'Kalian sedang bersama 💕');
    });

    test('LocationModel toFirestore contains required fields', () {
      final loc = LocationModel(
        uid: 'user_1',
        displayName: 'Kamu',
        latitude: -6.2088,
        longitude: 106.8456,
        placeLabel: 'Lagi Santai ☕',
        batteryLevel: 85,
        updatedAt: DateTime.now(),
      );

      final map = loc.toFirestore();
      expect(map['displayName'], 'Kamu');
      expect(map['latitude'], -6.2088);
      expect(map['longitude'], 106.8456);
      expect(map['placeLabel'], 'Lagi Santai ☕');
      expect(map['batteryLevel'], 85);
    });
  });

  group('NotificationModel Tests', () {
    test('NotificationModel serializes to firestore correctly', () {
      final notif = NotificationModel(
        id: 'notif_1',
        coupleId: 'couple_abc',
        senderUid: 'user_1',
        senderName: 'Alex',
        title: '📸 Alex mengirim PAP baru!',
        body: 'Lagi kangen kamu ❤️',
        type: 'pap',
        createdAt: DateTime.now(),
        isRead: false,
      );

      final map = notif.toFirestore();
      expect(map['coupleId'], 'couple_abc');
      expect(map['senderUid'], 'user_1');
      expect(map['title'], contains('PAP'));
      expect(map['type'], 'pap');
      expect(map['isRead'], false);
    });
  });

  group('PAP & Location Message Tests', () {
    test('MessageModel serializes pap and location fields', () {
      final papMsg = MessageModel(
        id: 'msg_pap',
        senderUid: 'user_1',
        type: 'pap',
        mediaUrl: 'data:image/jpeg;base64,mockBase64String',
        caption: 'PAP dari rumah',
        createdAt: DateTime.now(),
      );

      final papMap = papMsg.toFirestore();
      expect(papMap['type'], 'pap');
      expect(papMap['mediaUrl'], startsWith('data:image'));
      expect(papMap['caption'], 'PAP dari rumah');

      final locMsg = MessageModel(
        id: 'msg_loc',
        senderUid: 'user_1',
        type: 'location',
        latitude: -6.2088,
        longitude: 106.8456,
        placeLabel: 'Di Rumah 🏡',
        createdAt: DateTime.now(),
      );

      final locMap = locMsg.toFirestore();
      expect(locMap['type'], 'location');
      expect(locMap['latitude'], -6.2088);
      expect(locMap['longitude'], 106.8456);
      expect(locMap['placeLabel'], 'Di Rumah 🏡');
    });
  });
}
