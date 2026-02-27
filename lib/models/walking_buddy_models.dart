import 'package:cloud_firestore/cloud_firestore.dart';

/// Walking session status flow:
/// user -> destination search -> location confirmation ->
/// request sent (searching) -> volunteer_accepted -> user_confirmed ->
/// volunteer_reached -> journey_started -> destination_reached -> completed
enum WalkingSessionStatus {
  searching, // Awaiting volunteer acceptance
  volunteerAccepted, // Volunteer accepted, awaiting user confirmation
  userConfirmed, // User confirmed volunteer, en route
  volunteerReached, // Volunteer reached user location
  journeyStarted, // Both confirmed, journey to destination started
  destinationReached, // User reached destination
  completed, // Session ended successfully
  cancelled, // Session cancelled
}

/// Represents a walking buddy request/session
class WalkingSessionModel {
  final String sessionId;
  final String userId; // User requesting buddy
  final String userName;
  final String userPhone;
  final String? userPhotoUrl;
  final GeoPoint userLocation;
  final GeoPoint destinationLocation;
  final String destinationName;
  final String? destinationAddress;
  final WalkingSessionStatus status;

  // Volunteer information
  final String? volunteerId;
  final String? volunteerName;
  final String? volunteerPhone;
  final String? volunteerPhotoUrl;
  final double? distanceFromUser; // km

  // Timestamps
  final DateTime createdAt;
  final DateTime? volunteerAcceptedAt;
  final DateTime? userConfirmedAt;
  final DateTime? volunteerReachedAt;
  final DateTime? journeyStartedAt;
  final DateTime? destinationReachedAt;
  final DateTime? completedAt;

  // Additional metadata
  final bool userReachedDestination;
  final bool volunteerConfirmedArrival;
  final String? cancelReason;
  final double estimatedDuration; // minutes

  const WalkingSessionModel({
    required this.sessionId,
    required this.userId,
    required this.userName,
    required this.userPhone,
    this.userPhotoUrl,
    required this.userLocation,
    required this.destinationLocation,
    required this.destinationName,
    this.destinationAddress,
    this.status = WalkingSessionStatus.searching,
    this.volunteerId,
    this.volunteerName,
    this.volunteerPhone,
    this.volunteerPhotoUrl,
    this.distanceFromUser,
    required this.createdAt,
    this.volunteerAcceptedAt,
    this.userConfirmedAt,
    this.volunteerReachedAt,
    this.journeyStartedAt,
    this.destinationReachedAt,
    this.completedAt,
    this.userReachedDestination = false,
    this.volunteerConfirmedArrival = false,
    this.cancelReason,
    this.estimatedDuration = 30,
  });

  factory WalkingSessionModel.fromJson(Map<String, dynamic> json) {
    return WalkingSessionModel(
      sessionId: json['sessionId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      userPhone: json['userPhone'] as String,
      userPhotoUrl: json['userPhotoUrl'] as String?,
      userLocation: json['userLocation'] as GeoPoint,
      destinationLocation: json['destinationLocation'] as GeoPoint,
      destinationName: json['destinationName'] as String,
      destinationAddress: json['destinationAddress'] as String?,
      status: _parseStatus(json['status'] as String?),
      volunteerId: json['volunteerId'] as String?,
      volunteerName: json['volunteerName'] as String?,
      volunteerPhone: json['volunteerPhone'] as String?,
      volunteerPhotoUrl: json['volunteerPhotoUrl'] as String?,
      distanceFromUser: (json['distanceFromUser'] as num?)?.toDouble(),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      volunteerAcceptedAt: json['volunteerAcceptedAt'] != null
          ? (json['volunteerAcceptedAt'] as Timestamp).toDate()
          : null,
      userConfirmedAt: json['userConfirmedAt'] != null
          ? (json['userConfirmedAt'] as Timestamp).toDate()
          : null,
      volunteerReachedAt: json['volunteerReachedAt'] != null
          ? (json['volunteerReachedAt'] as Timestamp).toDate()
          : null,
      journeyStartedAt: json['journeyStartedAt'] != null
          ? (json['journeyStartedAt'] as Timestamp).toDate()
          : null,
      destinationReachedAt: json['destinationReachedAt'] != null
          ? (json['destinationReachedAt'] as Timestamp).toDate()
          : null,
      completedAt: json['completedAt'] != null
          ? (json['completedAt'] as Timestamp).toDate()
          : null,
      userReachedDestination: json['userReachedDestination'] as bool? ?? false,
      volunteerConfirmedArrival:
          json['volunteerConfirmedArrival'] as bool? ?? false,
      cancelReason: json['cancelReason'] as String?,
      estimatedDuration: (json['estimatedDuration'] as num?)?.toDouble() ?? 30,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'userPhotoUrl': userPhotoUrl,
        'userLocation': userLocation,
        'destinationLocation': destinationLocation,
        'destinationName': destinationName,
        'destinationAddress': destinationAddress,
        'status': status.name,
        'volunteerId': volunteerId,
        'volunteerName': volunteerName,
        'volunteerPhone': volunteerPhone,
        'volunteerPhotoUrl': volunteerPhotoUrl,
        'distanceFromUser': distanceFromUser,
        'createdAt': Timestamp.fromDate(createdAt),
        'volunteerAcceptedAt': volunteerAcceptedAt != null
            ? Timestamp.fromDate(volunteerAcceptedAt!)
            : null,
        'userConfirmedAt': userConfirmedAt != null
            ? Timestamp.fromDate(userConfirmedAt!)
            : null,
        'volunteerReachedAt': volunteerReachedAt != null
            ? Timestamp.fromDate(volunteerReachedAt!)
            : null,
        'journeyStartedAt': journeyStartedAt != null
            ? Timestamp.fromDate(journeyStartedAt!)
            : null,
        'destinationReachedAt': destinationReachedAt != null
            ? Timestamp.fromDate(destinationReachedAt!)
            : null,
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'userReachedDestination': userReachedDestination,
        'volunteerConfirmedArrival': volunteerConfirmedArrival,
        'cancelReason': cancelReason,
        'estimatedDuration': estimatedDuration,
      };

  WalkingSessionModel copyWith({
    String? sessionId,
    String? userId,
    String? userName,
    String? userPhone,
    String? userPhotoUrl,
    GeoPoint? userLocation,
    GeoPoint? destinationLocation,
    String? destinationName,
    String? destinationAddress,
    WalkingSessionStatus? status,
    String? volunteerId,
    String? volunteerName,
    String? volunteerPhone,
    String? volunteerPhotoUrl,
    double? distanceFromUser,
    DateTime? createdAt,
    DateTime? volunteerAcceptedAt,
    DateTime? userConfirmedAt,
    DateTime? volunteerReachedAt,
    DateTime? journeyStartedAt,
    DateTime? destinationReachedAt,
    DateTime? completedAt,
    bool? userReachedDestination,
    bool? volunteerConfirmedArrival,
    String? cancelReason,
    double? estimatedDuration,
  }) {
    return WalkingSessionModel(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      userLocation: userLocation ?? this.userLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      destinationName: destinationName ?? this.destinationName,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      status: status ?? this.status,
      volunteerId: volunteerId ?? this.volunteerId,
      volunteerName: volunteerName ?? this.volunteerName,
      volunteerPhone: volunteerPhone ?? this.volunteerPhone,
      volunteerPhotoUrl: volunteerPhotoUrl ?? this.volunteerPhotoUrl,
      distanceFromUser: distanceFromUser ?? this.distanceFromUser,
      createdAt: createdAt ?? this.createdAt,
      volunteerAcceptedAt: volunteerAcceptedAt ?? this.volunteerAcceptedAt,
      userConfirmedAt: userConfirmedAt ?? this.userConfirmedAt,
      volunteerReachedAt: volunteerReachedAt ?? this.volunteerReachedAt,
      journeyStartedAt: journeyStartedAt ?? this.journeyStartedAt,
      destinationReachedAt: destinationReachedAt ?? this.destinationReachedAt,
      completedAt: completedAt ?? this.completedAt,
      userReachedDestination:
          userReachedDestination ?? this.userReachedDestination,
      volunteerConfirmedArrival:
          volunteerConfirmedArrival ?? this.volunteerConfirmedArrival,
      cancelReason: cancelReason ?? this.cancelReason,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
    );
  }

  static WalkingSessionStatus _parseStatus(String? status) {
    switch (status) {
      case 'searching':
        return WalkingSessionStatus.searching;
      case 'volunteerAccepted':
        return WalkingSessionStatus.volunteerAccepted;
      case 'userConfirmed':
        return WalkingSessionStatus.userConfirmed;
      case 'volunteerReached':
        return WalkingSessionStatus.volunteerReached;
      case 'journeyStarted':
        return WalkingSessionStatus.journeyStarted;
      case 'destinationReached':
        return WalkingSessionStatus.destinationReached;
      case 'completed':
        return WalkingSessionStatus.completed;
      case 'cancelled':
        return WalkingSessionStatus.cancelled;
      default:
        return WalkingSessionStatus.searching;
    }
  }
}

/// Represents a destination location (search result from Google Places)
class DestinationModel {
  final String placeId;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String? photoUrl;

  const DestinationModel({
    required this.placeId,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.photoUrl,
  });

  GeoPoint toGeoPoint() => GeoPoint(latitude, longitude);
}

/// Walking buddy volunteer availability model
class VolunteerAvailabilityModel {
  final String volunteerId;
  final String volunteerName;
  final String? photoUrl;
  final String phone;
  final GeoPoint currentLocation;
  final double distanceFromUser; // km
  final String verificationStatus; // verified, unverified
  final int sessionsCompleted;
  final double averageRating; // 1-5

  const VolunteerAvailabilityModel({
    required this.volunteerId,
    required this.volunteerName,
    this.photoUrl,
    required this.phone,
    required this.currentLocation,
    required this.distanceFromUser,
    this.verificationStatus = 'unverified',
    this.sessionsCompleted = 0,
    this.averageRating = 0,
  });

  factory VolunteerAvailabilityModel.fromJson(Map<String, dynamic> json) {
    return VolunteerAvailabilityModel(
      volunteerId: json['uid'] as String,
      volunteerName: json['name'] as String,
      photoUrl: json['photoUrl'] as String?,
      phone: json['phone'] as String,
      currentLocation: json['currentLocation'] as GeoPoint,
      distanceFromUser: (json['distanceFromUser'] as num).toDouble(),
      verificationStatus: json['verificationStatus'] as String? ?? 'unverified',
      sessionsCompleted: json['sessionsCompleted'] as int? ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Live location update for walking buddy tracking
class WalkingBuddyLocationUpdate {
  final String sessionId;
  final String userId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;
  final double? altitude;
  final double? speed;

  const WalkingBuddyLocationUpdate({
    required this.sessionId,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.altitude,
    this.speed,
  });

  GeoPoint toGeoPoint() => GeoPoint(latitude, longitude);

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'userId': userId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': Timestamp.fromDate(timestamp),
        'accuracy': accuracy,
        'altitude': altitude,
        'speed': speed,
      };
}
