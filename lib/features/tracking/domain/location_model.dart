import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class LocationModel {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final double latitude;
  final double longitude;
  final String? placeLabel;
  final int? batteryLevel;
  final bool isLive;
  final DateTime updatedAt;

  const LocationModel({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.latitude,
    required this.longitude,
    this.placeLabel,
    this.batteryLevel,
    this.isLive = false,
    required this.updatedAt,
  });

  double distanceTo(LocationModel other) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  String formattedDistanceTo(LocationModel other) {
    final distMeters = distanceTo(other);
    if (distMeters < 50) {
      return 'Kalian sedang bersama 💕';
    } else if (distMeters < 1000) {
      return '${distMeters.round()} m dari kamu';
    } else {
      return '${(distMeters / 1000).toStringAsFixed(1)} km dari kamu';
    }
  }

  factory LocationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return LocationModel(
      uid: snapshot.id,
      displayName: data['displayName'] as String? ?? 'User',
      photoUrl: data['photoUrl'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      placeLabel: data['placeLabel'] as String?,
      batteryLevel: data['batteryLevel'] as int?,
      isLive: data['isLive'] as bool? ?? false,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'placeLabel': placeLabel,
      'batteryLevel': batteryLevel,
      'isLive': isLive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
