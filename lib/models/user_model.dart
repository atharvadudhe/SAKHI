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
  final GeoPoint? liveLocation;
  final DateTime? lastHeartbeat;
  final bool verifiedStatus;

  // ── Duress PIN fields ──
  final String? safePin;
  final String? duressPin;

  // ── Profile picture ──
  final String? photoUrl;

  // ── KYC verification ──
  final VerificationStatus verificationStatus;
  final String? idFrontUrl;
  final String? idBackUrl;
  final DateTime? verificationSubmittedAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.role = UserRole.user,
    this.isAvailable = false,
    this.currentLocation,
    this.liveLocation,
    this.lastHeartbeat,
    this.verifiedStatus = false,
    this.safePin,
    this.duressPin,
    this.photoUrl,
    this.verificationStatus = VerificationStatus.unverified,
    this.idFrontUrl,
    this.idBackUrl,
    this.verificationSubmittedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String? ?? '',
      role: _parseRole(json['role'] as String?),
      isAvailable: json['isAvailable'] as bool? ?? false,
      currentLocation: json['currentLocation'] as GeoPoint?,
      liveLocation: json['liveLocation'] as GeoPoint?,
      lastHeartbeat: json['lastHeartbeat'] != null
          ? (json['lastHeartbeat'] as Timestamp).toDate()
          : null,
      verifiedStatus: json['verifiedStatus'] as bool? ?? false,
      safePin: json['safePin'] as String?,
      duressPin: json['duressPin'] as String?,
      photoUrl: json['photoUrl'] as String?,
      verificationStatus: _parseVerificationStatus(
        json['verificationStatus'] as String?,
      ),
      idFrontUrl: json['idFrontUrl'] as String?,
      idBackUrl: json['idBackUrl'] as String?,
      verificationSubmittedAt: json['verificationSubmittedAt'] != null
          ? (json['verificationSubmittedAt'] as Timestamp).toDate()
          : null,
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
    'photoUrl': photoUrl,
    'verificationStatus': verificationStatus.name,
    'idFrontUrl': idFrontUrl,
    'idBackUrl': idBackUrl,
    'verificationSubmittedAt': verificationSubmittedAt != null
        ? Timestamp.fromDate(verificationSubmittedAt!)
        : null,
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
    String? photoUrl,
    VerificationStatus? verificationStatus,
    String? idFrontUrl,
    String? idBackUrl,
    DateTime? verificationSubmittedAt,
    bool clearSafePin = false,
    bool clearDuressPin = false,
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
      safePin: clearSafePin ? null : (safePin ?? this.safePin),
      duressPin: clearDuressPin ? null : (duressPin ?? this.duressPin),
      photoUrl: photoUrl ?? this.photoUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      idFrontUrl: idFrontUrl ?? this.idFrontUrl,
      idBackUrl: idBackUrl ?? this.idBackUrl,
      verificationSubmittedAt: verificationSubmittedAt ?? this.verificationSubmittedAt,
    );
  }

  /// Whether the user has configured both PINs for duress cancellation.
  /// Requires both PINs to be non-null, exactly 4 digits, numeric-only,
  /// and different from each other.
  bool get hasDuressPinSetup {
    final digitPattern = RegExp(r'^\d{4}$');
    return safePin != null &&
        digitPattern.hasMatch(safePin!) &&
        duressPin != null &&
        digitPattern.hasMatch(duressPin!) &&
        safePin != duressPin;
  }
}
