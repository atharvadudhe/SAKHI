import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a walk request in broadcast architecture
enum WalkingRequestStatus { searching, accepted, rejected }

/// Simplified request used by both user and volunteer
class WalkingRequestModel {
  final String requestId;
  final String requesterId;
  final String requesterName;
  final String requesterPhone;
  final String? requesterPhotoUrl;
  final GeoPoint requesterLocation;
  final double distanceToRequester;
  final WalkingRequestStatus status;
  final String? acceptedBy; // volunteer UID if someone accepted
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? userConfirmedAt;
  final bool volunteerConfirmedArrival;

  const WalkingRequestModel({
    required this.requestId,
    required this.requesterId,
    required this.requesterName,
    this.requesterPhone = '',
    this.requesterPhotoUrl,
    required this.requesterLocation,
    this.distanceToRequester = 0.0,
    this.status = WalkingRequestStatus.searching,
    this.acceptedBy,
    required this.createdAt,
    this.acceptedAt,
    this.userConfirmedAt,
    this.volunteerConfirmedArrival = false,
  });

  factory WalkingRequestModel.fromJson(Map<String, dynamic> json) {
    return WalkingRequestModel(
      requestId: (json['requestId'] ?? json['sessionId']) as String,
      requesterId: (json['requesterId'] ?? json['userId']) as String,
      requesterName:
          (json['requesterName'] ?? json['userName'] ?? 'Unknown') as String,
      requesterPhone: (json['requesterPhone'] ?? json['userPhone'] ?? '')
          as String,
      requesterPhotoUrl:
          (json['requesterPhotoUrl'] ?? json['userPhotoUrl']) as String?,
      requesterLocation:
          (json['requesterLocation'] ?? json['userLocation']) as GeoPoint,
      distanceToRequester: (json['distanceToRequester'] as num?)?.toDouble() ??
          (json['distanceFromUser'] as num?)?.toDouble() ??
          0.0,
      status: _parseStatus(json['status'] as String?),
      acceptedBy: (json['acceptedBy'] ?? json['volunteerId']) as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      acceptedAt:
          (json['acceptedAt'] ?? json['volunteerAcceptedAt']) != null
              ? ((json['acceptedAt'] ?? json['volunteerAcceptedAt'])
                      as Timestamp)
                  .toDate()
          : null,
      userConfirmedAt: json['userConfirmedAt'] != null
          ? (json['userConfirmedAt'] as Timestamp).toDate()
          : null,
      volunteerConfirmedArrival:
          json['volunteerConfirmedArrival'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'requesterPhone': requesterPhone,
        'requesterPhotoUrl': requesterPhotoUrl,
        'requesterLocation': requesterLocation,
        'distanceToRequester': distanceToRequester,
        'status': status.name,
        'acceptedBy': acceptedBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'acceptedAt':
            acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
        'userConfirmedAt':
            userConfirmedAt != null ? Timestamp.fromDate(userConfirmedAt!) : null,
        'volunteerConfirmedArrival': volunteerConfirmedArrival,
      };

  static WalkingRequestStatus _parseStatus(String? value) {
    switch (value) {
      case 'accepted':
        return WalkingRequestStatus.accepted;
      case 'rejected':
        return WalkingRequestStatus.rejected;
      case 'pending':
      default:
        return WalkingRequestStatus.searching;
    }
  }
}
