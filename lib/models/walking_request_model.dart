import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a walk request in broadcast architecture
enum WalkingRequestStatus { searching, accepted, rejected }

/// Simplified request used by both user and volunteer
class WalkingRequestModel {
  final String requestId;
  final String requesterId;
  final String requesterName;
  final GeoPoint requesterLocation;
  final WalkingRequestStatus status;
  final String? acceptedBy; // volunteer UID if someone accepted
  final DateTime createdAt;
  final DateTime? acceptedAt;

  const WalkingRequestModel({
    required this.requestId,
    required this.requesterId,
    required this.requesterName,
    required this.requesterLocation,
    this.status = WalkingRequestStatus.searching,
    this.acceptedBy,
    required this.createdAt,
    this.acceptedAt,
  });

  factory WalkingRequestModel.fromJson(Map<String, dynamic> json) {
    return WalkingRequestModel(
      requestId: json['requestId'] as String,
      requesterId: json['requesterId'] as String,
      requesterName: json['requesterName'] as String,
      requesterLocation: json['requesterLocation'] as GeoPoint,
      status: _parseStatus(json['status'] as String?),
      acceptedBy: json['acceptedBy'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      acceptedAt: json['acceptedAt'] != null
          ? (json['acceptedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'requesterLocation': requesterLocation,
        'status': status.name,
        'acceptedBy': acceptedBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'acceptedAt':
            acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
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
