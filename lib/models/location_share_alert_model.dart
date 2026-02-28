import 'package:cloud_firestore/cloud_firestore.dart';

class LocationShareAlertModel {
  final String alertId;
  final String shareId;
  final String senderUid;
  final String senderName;
  final String senderPhone;
  final String recipientUid;
  final String recipientPhone;
  final String status;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const LocationShareAlertModel({
    required this.alertId,
    required this.shareId,
    required this.senderUid,
    required this.senderName,
    required this.senderPhone,
    required this.recipientUid,
    required this.recipientPhone,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isActive => status == 'active';

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  factory LocationShareAlertModel.fromJson(Map<String, dynamic> json) {
    DateTime? toDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return null;
    }

    return LocationShareAlertModel(
      alertId: json['alertId'] as String? ?? '',
      shareId: json['shareId'] as String? ?? '',
      senderUid: json['senderUid'] as String? ?? '',
      senderName: json['senderName'] as String? ?? 'Unknown',
      senderPhone: json['senderPhone'] as String? ?? '',
      recipientUid: json['recipientUid'] as String? ?? '',
      recipientPhone: json['recipientPhone'] as String? ?? '',
      status: json['status'] as String? ?? 'ended',
      createdAt: toDate(json['createdAt']),
      expiresAt: toDate(json['expiresAt']),
    );
  }
}
