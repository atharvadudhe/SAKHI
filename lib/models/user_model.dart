import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, volunteer, admin }

/// KYC verification status for volunteers.
enum VerificationStatus { unverified, pending, verified, rejected }

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final UserRole role;
  final bool isAvailable;
  final GeoPoint? currentLocation;
  final DateTime? lastHeartbeat;
  final bool verifiedStatus;

  // ── Duress PIN fields ──
  final String? safePin;
  final String? duressPin;

  // ── KYC verification ──
  final VerificationStatus verificationStatus;

  const UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.role = UserRole.user,
    this.isAvailable = false,
    this.currentLocation,
    this.lastHeartbeat,
    this.verifiedStatus = false,
    this.safePin,
    this.duressPin,
    this.verificationStatus = VerificationStatus.unverified,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String? ?? '',
      role: _parseRole(json['role'] as String?),
      isAvailable: json['isAvailable'] as bool? ?? false,
      currentLocation: json['currentLocation'] as GeoPoint?,
      lastHeartbeat: json['lastHeartbeat'] != null
          ? (json['lastHeartbeat'] as Timestamp).toDate()
          : null,
      verifiedStatus: json['verifiedStatus'] as bool? ?? false,
      safePin: json['safePin'] as String?,
      duressPin: json['duressPin'] as String?,
      verificationStatus: _parseVerificationStatus(
        json['verificationStatus'] as String?,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'phone': phone,
    'role': role.name,
    'isAvailable': isAvailable,
    'currentLocation': currentLocation,
    'lastHeartbeat': lastHeartbeat != null
        ? Timestamp.fromDate(lastHeartbeat!)
        : null,
    'verifiedStatus': verifiedStatus,
    'safePin': safePin,
    'duressPin': duressPin,
    'verificationStatus': verificationStatus.name,
  };

  static UserRole _parseRole(String? value) {
    switch (value) {
      case 'volunteer':
        return UserRole.volunteer;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.user;
    }
  }

  static VerificationStatus _parseVerificationStatus(String? value) {
    switch (value) {
      case 'pending':
        return VerificationStatus.pending;
      case 'verified':
        return VerificationStatus.verified;
      case 'rejected':
        return VerificationStatus.rejected;
      default:
        return VerificationStatus.unverified;
    }
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? phone,
    UserRole? role,
    bool? isAvailable,
    GeoPoint? currentLocation,
    DateTime? lastHeartbeat,
    bool? verifiedStatus,
    String? safePin,
    String? duressPin,
    VerificationStatus? verificationStatus,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLocation: currentLocation ?? this.currentLocation,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      verifiedStatus: verifiedStatus ?? this.verifiedStatus,
      safePin: safePin ?? this.safePin,
      duressPin: duressPin ?? this.duressPin,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }

  /// Whether the user has configured both PINs for duress cancellation.
  bool get hasDuressPinSetup =>
      safePin != null &&
      safePin!.length == 4 &&
      duressPin != null &&
      duressPin!.length == 4;
}
