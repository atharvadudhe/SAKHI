import 'package:cloud_firestore/cloud_firestore.dart';

class LocationUpdate {
  final String uid;
  final GeoPoint geoPoint;
  final DateTime timestamp;

  const LocationUpdate({
    required this.uid,
    required this.geoPoint,
    required this.timestamp,
  });

  factory LocationUpdate.fromJson(Map<String, dynamic> json) {
    return LocationUpdate(
      uid: json['uid'] as String,
      geoPoint: json['geoPoint'] as GeoPoint,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'geoPoint': geoPoint,
    'timestamp': Timestamp.fromDate(timestamp),
  };
}
