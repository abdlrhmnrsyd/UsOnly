import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../domain/location_model.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) => LocationRepository());

class LocationRepository {
  final FirebaseFirestore? _customFirestore;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _heartbeatTimer;
  bool _isLive = false;
  final ValueNotifier<bool> liveSharingNotifier = ValueNotifier<bool>(false);

  LocationRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  bool get isLiveSharing => _isLive;

  Stream<Map<String, LocationModel>> watchCoupleLocations(String coupleId) {
    return _firestore
        .collection('coupleSpaces')
        .doc(coupleId)
        .collection('locations')
        .snapshots()
        .map((snapshot) {
      final map = <String, LocationModel>{};
      for (var doc in snapshot.docs) {
        map[doc.id] = LocationModel.fromFirestore(doc);
      }
      return map;
    }).handleError((error) {
      return <String, LocationModel>{};
    });
  }

  Future<Position?> getCurrentDevicePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Continue to check permissions gracefully
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('Geolocator notice: $e');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Turn ON Live Location sharing.
  /// Automatically streams position to Firestore in real-time as long as it's ON.
  Future<void> startLiveSharing({
    required String coupleId,
    required String uid,
    required String displayName,
    String? photoUrl,
    String? placeLabel,
  }) async {
    _isLive = true;
    liveSharingNotifier.value = true;

    // Immediately push first coordinate
    try {
      await updateLocation(
        coupleId: coupleId,
        uid: uid,
        displayName: displayName,
        photoUrl: photoUrl,
        placeLabel: placeLabel,
        isLive: true,
      );
    } catch (e) {
      debugPrint('Initial live coordinate notice: $e');
    }

    // Cancel any previous stream
    await _positionSubscription?.cancel();
    _heartbeatTimer?.cancel();

    // Listen to real-time device movement
    try {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // update every 5 meters
        ),
      ).listen((pos) {
        if (_isLive) {
          updateLocation(
            coupleId: coupleId,
            uid: uid,
            displayName: displayName,
            photoUrl: photoUrl,
            placeLabel: placeLabel,
            manualLat: pos.latitude,
            manualLng: pos.longitude,
            isLive: true,
          );
        }
      }, onError: (err) {
        debugPrint('Geolocator stream notice: $err');
      });
    } catch (e) {
      debugPrint('Could not start GPS stream: $e');
    }

    // Keep periodic 10-second heartbeat so timestamp stays fresh even when stationary
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_isLive) {
        final pos = await getCurrentDevicePosition();
        if (_isLive) {
          updateLocation(
            coupleId: coupleId,
            uid: uid,
            displayName: displayName,
            photoUrl: photoUrl,
            placeLabel: placeLabel,
            manualLat: pos?.latitude,
            manualLng: pos?.longitude,
            isLive: true,
          );
        }
      }
    });
  }

  /// Turn OFF Live Location sharing.
  Future<void> stopLiveSharing({
    required String coupleId,
    required String uid,
  }) async {
    _isLive = false;
    liveSharingNotifier.value = false;
    await _positionSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _positionSubscription = null;
    _heartbeatTimer = null;

    try {
      await _firestore
          .collection('coupleSpaces')
          .doc(coupleId)
          .collection('locations')
          .doc(uid)
          .set({'isLive': false, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Stop live sharing notice: $e');
    }
  }

  Future<LocationModel?> updateLocation({
    required String coupleId,
    required String uid,
    required String displayName,
    String? photoUrl,
    String? placeLabel,
    double? manualLat,
    double? manualLng,
    bool isLive = false,
  }) async {
    double lat = manualLat ?? 0.0;
    double lng = manualLng ?? 0.0;

    if (manualLat == null || manualLng == null) {
      final pos = await getCurrentDevicePosition();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
      } else {
        lat = -6.2088; // Default Jakarta
        lng = 106.8456;
      }
    }

    final locRef = _firestore
        .collection('coupleSpaces')
        .doc(coupleId)
        .collection('locations')
        .doc(uid);

    final model = LocationModel(
      uid: uid,
      displayName: displayName,
      photoUrl: photoUrl,
      latitude: lat,
      longitude: lng,
      placeLabel: placeLabel ?? 'Di Rumah 🏡',
      batteryLevel: 88,
      isLive: isLive,
      updatedAt: DateTime.now(),
    );

    try {
      await locRef.set(model.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('locRef set error notice: $e');
    }
    return model;
  }
}
