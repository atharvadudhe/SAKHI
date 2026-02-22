import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, volunteer }

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final UserRole role;
  final bool isAvailable;
  final GeoPoint? currentLocation;
  final DateTime? lastHeartbeat;
  final bool verifiedStatus;

  const UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.role = UserRole.user,
    this.isAvailable = false,
    this.currentLocation,
    this.lastHeartbeat,
    this.verifiedStatus = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String? ?? '',
      role: json['role'] == 'volunteer' ? UserRole.volunteer : UserRole.user,
      isAvailable: json['isAvailable'] as bool? ?? false,
      currentLocation: json['currentLocation'] as GeoPoint?,
      lastHeartbeat: json['lastHeartbeat'] != null
          ? (json['lastHeartbeat'] as Timestamp).toDate()
          : null,
      verifiedStatus: json['verifiedStatus'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'phone': phone,
    'role': role == UserRole.volunteer ? 'volunteer' : 'user',
    'isAvailable': isAvailable,
    'currentLocation': currentLocation,
    'lastHeartbeat': lastHeartbeat != null
        ? Timestamp.fromDate(lastHeartbeat!)
        : null,
    'verifiedStatus': verifiedStatus,
  };

  UserModel copyWith({
    String? uid,
    String? name,
    String? phone,
    UserRole? role,
    bool? isAvailable,
    GeoPoint? currentLocation,
    DateTime? lastHeartbeat,
    bool? verifiedStatus,
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
    );
  }
}
