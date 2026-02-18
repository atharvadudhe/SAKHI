import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionStatus { searching, active, ended, sosTriggered }

class SessionModel {
  final String sessionId;
  final String createdBy;
  final SessionStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final String? volunteerId;
  final String? volunteerName;
  final int timeLimit; // minutes
  final DateTime lastUpdate;
  final GeoPoint? destinationLocation;
  final GeoPoint? userLocation;

  const SessionModel({
    required this.sessionId,
    required this.createdBy,
    required this.status,
    required this.startTime,
    this.endTime,
    this.volunteerId,
    this.volunteerName,
    this.timeLimit = 30,
    required this.lastUpdate,
    this.destinationLocation,
    this.userLocation,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      sessionId: json['sessionId'] as String,
      createdBy: json['createdBy'] as String,
      status: _parseStatus(json['status'] as String?),
      startTime: (json['startTime'] as Timestamp).toDate(),
      endTime: json['endTime'] != null
          ? (json['endTime'] as Timestamp).toDate()
          : null,
      volunteerId: json['volunteerId'] as String?,
      volunteerName: json['volunteerName'] as String?,
      timeLimit: json['timeLimit'] as int? ?? 30,
      lastUpdate: (json['lastUpdate'] as Timestamp).toDate(),
      destinationLocation: json['destinationLocation'] as GeoPoint?,
      userLocation: json['userLocation'] as GeoPoint?,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'createdBy': createdBy,
        'status': status.name,
        'startTime': Timestamp.fromDate(startTime),
        'endTime':
            endTime != null ? Timestamp.fromDate(endTime!) : null,
        'volunteerId': volunteerId,
        'volunteerName': volunteerName,
        'timeLimit': timeLimit,
        'lastUpdate': Timestamp.fromDate(lastUpdate),
        'destinationLocation': destinationLocation,
        'userLocation': userLocation,
      };

  static SessionStatus _parseStatus(String? status) {
    switch (status) {
      case 'searching':
        return SessionStatus.searching;
      case 'active':
        return SessionStatus.active;
      case 'ended':
        return SessionStatus.ended;
      case 'sosTriggered':
        return SessionStatus.sosTriggered;
      default:
        return SessionStatus.searching;
    }
  }

  SessionModel copyWith({
    String? sessionId,
    String? createdBy,
    SessionStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    String? volunteerId,
    String? volunteerName,
    int? timeLimit,
    DateTime? lastUpdate,
    GeoPoint? destinationLocation,
    GeoPoint? userLocation,
  }) {
    return SessionModel(
      sessionId: sessionId ?? this.sessionId,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      volunteerId: volunteerId ?? this.volunteerId,
      volunteerName: volunteerName ?? this.volunteerName,
      timeLimit: timeLimit ?? this.timeLimit,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      destinationLocation:
          destinationLocation ?? this.destinationLocation,
      userLocation: userLocation ?? this.userLocation,
    );
  }

  bool get isActive => status == SessionStatus.active;
  bool get isSearching => status == SessionStatus.searching;
  bool get isSOS => status == SessionStatus.sosTriggered;

  Duration get elapsed => DateTime.now().difference(startTime);
  Duration get remaining =>
      Duration(minutes: timeLimit) - elapsed;
}
