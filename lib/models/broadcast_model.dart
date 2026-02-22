import 'package:cloud_firestore/cloud_firestore.dart';

class BroadcastModel {
  final String id;
  final String uid;
  final String? userName;
  final String message;
  final String alertType;
  final GeoPoint location;
  final DateTime? timestamp;
  final double radiusKm;

  const BroadcastModel({
    required this.id,
    required this.uid,
    this.userName,
    required this.message,
    required this.alertType,
    required this.location,
    this.timestamp,
    this.radiusKm = 2.0,
  });

  factory BroadcastModel.fromJson(Map<String, dynamic> json) {
    final rawTs = json['timestamp'];
    DateTime? parsedTimestamp;
    if (rawTs is Timestamp) {
      parsedTimestamp = rawTs.toDate();
    } else if (rawTs is DateTime) {
      parsedTimestamp = rawTs;
    }

    return BroadcastModel(
      id: json['id'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      userName: json['userName'] as String?,
      message: json['message'] as String? ?? '',
      alertType: json['alertType'] as String? ?? 'unsafe_area',
      location: json['location'] as GeoPoint? ?? const GeoPoint(0, 0),
      timestamp: parsedTimestamp,
      radiusKm: (json['radiusKm'] as num?)?.toDouble() ?? 2.0,
    );
  }

  /// Pure-data JSON (safe for serialisation / logging).
  Map<String, dynamic> toJson() => {
    'id': id,
    'uid': uid,
    'userName': userName,
    'message': message,
    'alertType': alertType,
    'location': location,
    'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
    'radiusKm': radiusKm,
  };

  /// Firestore-specific map — uses server timestamp when none is set.
  Map<String, dynamic> toFirestore() => {
    'id': id,
    'uid': uid,
    'userName': userName,
    'message': message,
    'alertType': alertType,
    'location': location,
    'timestamp': timestamp != null
        ? Timestamp.fromDate(timestamp!)
        : FieldValue.serverTimestamp(),
    'radiusKm': radiusKm,
  };

  String get alertLabel {
    switch (alertType) {
      case 'unsafe_area':
        return 'Unsafe Area';
      case 'suspicious_activity':
        return 'Suspicious Activity';
      case 'need_help':
        return 'Need Help';
      case 'road_issue':
        return 'Road Issue';
      default:
        return alertType;
    }
  }

  String get timeAgo {
    if (timestamp == null) return 'Just now';
    final diff = DateTime.now().difference(timestamp!);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
