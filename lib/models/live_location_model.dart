import 'package:cloud_firestore/cloud_firestore.dart';

/// Reason why a user's live location is being tracked.
enum TrackingReason {
  /// Regular safety session (walk with me, companion, etc.)
  session,

  /// Active SOS — highest priority, shown as red on admin map.
  sos,

  /// Volunteer on duty / available and responding.
  volunteerDuty,
}

/// Dedicated model for the `liveLocations` Firestore collection.
///
/// This is intentionally separated from [UserModel] so that:
///   1. Admin can query *only* active trackers without scanning all users.
///   2. We can add tracking-specific fields (reason, battery, sessionId)
///      without bloating the user document.
class LiveLocationModel {
  final String uid;
  final String userName;
  final String role; // 'user' | 'volunteer' | 'admin'
  final double latitude;
  final double longitude;
  final DateTime lastUpdatedAt;
  final bool isActive;
  final TrackingReason trackingReason;
  final String? sessionId;
  final int? batteryLevel; // 0-100, null if unavailable

  const LiveLocationModel({
    required this.uid,
    required this.userName,
    required this.role,
    required this.latitude,
    required this.longitude,
    required this.lastUpdatedAt,
    this.isActive = true,
    this.trackingReason = TrackingReason.session,
    this.sessionId,
    this.batteryLevel,
  });

  factory LiveLocationModel.fromJson(Map<String, dynamic> json) {
    final rawTs = json['lastUpdatedAt'];
    DateTime parsedTs;
    if (rawTs is Timestamp) {
      parsedTs = rawTs.toDate();
    } else if (rawTs is DateTime) {
      parsedTs = rawTs;
    } else {
      parsedTs = DateTime.now();
    }

    return LiveLocationModel(
      uid: json['uid'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Unknown',
      role: json['role'] as String? ?? 'user',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      lastUpdatedAt: parsedTs,
      isActive: json['isActive'] as bool? ?? true,
      trackingReason: _parseReason(json['trackingReason'] as String?),
      sessionId: json['sessionId'] as String?,
      batteryLevel: json['batteryLevel'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'userName': userName,
        'role': role,
        'latitude': latitude,
        'longitude': longitude,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'isActive': isActive,
        'trackingReason': trackingReason.name,
        'sessionId': sessionId,
        'batteryLevel': batteryLevel,
      };

  /// Variant that embeds the client-side timestamp (for offline / testing).
  Map<String, dynamic> toJsonWithClientTs() => {
        'uid': uid,
        'userName': userName,
        'role': role,
        'latitude': latitude,
        'longitude': longitude,
        'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt),
        'isActive': isActive,
        'trackingReason': trackingReason.name,
        'sessionId': sessionId,
        'batteryLevel': batteryLevel,
      };

  LiveLocationModel copyWith({
    String? uid,
    String? userName,
    String? role,
    double? latitude,
    double? longitude,
    DateTime? lastUpdatedAt,
    bool? isActive,
    TrackingReason? trackingReason,
    String? sessionId,
    int? batteryLevel,
  }) {
    return LiveLocationModel(
      uid: uid ?? this.uid,
      userName: userName ?? this.userName,
      role: role ?? this.role,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      isActive: isActive ?? this.isActive,
      trackingReason: trackingReason ?? this.trackingReason,
      sessionId: sessionId ?? this.sessionId,
      batteryLevel: batteryLevel ?? this.batteryLevel,
    );
  }

  static TrackingReason _parseReason(String? value) {
    switch (value) {
      case 'sos':
        return TrackingReason.sos;
      case 'volunteerDuty':
        return TrackingReason.volunteerDuty;
      case 'session':
      default:
        return TrackingReason.session;
    }
  }

  /// Human-readable elapsed time since last update.
  String get timeSinceUpdate {
    final diff = DateTime.now().difference(lastUpdatedAt);
    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
