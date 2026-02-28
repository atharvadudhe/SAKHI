import 'package:cloud_firestore/cloud_firestore.dart';

class LocationShareModel {
  final String id;
  final String uid;
  final String userName;
  final String senderPhone;
  final GeoPoint location;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final bool isActive;
  final List<String> recipientUids;
  final List<String> recipientPhones;

  const LocationShareModel({
    required this.id,
    required this.uid,
    required this.userName,
    required this.senderPhone,
    required this.location,
    required this.createdAt,
    required this.expiresAt,
    required this.isActive,
    required this.recipientUids,
    required this.recipientPhones,
  });

  factory LocationShareModel.fromJson(Map<String, dynamic> json) {
    DateTime? toDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return null;
    }

    return LocationShareModel(
      id: json['id'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Unknown',
      senderPhone: json['senderPhone'] as String? ?? '',
      location: json['location'] as GeoPoint? ?? GeoPoint(0, 0),
      createdAt: toDate(json['createdAt']),
      expiresAt: toDate(json['expiresAt']),
      isActive: json['isActive'] as bool? ?? false,
      recipientUids: (json['recipientUids'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      recipientPhones: (json['recipientPhones'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
    );
  }
}
