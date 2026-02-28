import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../models/emergency_contact.dart';
import 'firestore_service.dart';
import 'location_service.dart';

class InternalHeartbeatState {
  final int intervalMinutes;
  final bool isMonitoring;
  final bool isTriggeringSos;
  final bool sosTriggered;
  final DateTime? expiresAt;

  const InternalHeartbeatState({
    required this.intervalMinutes,
    required this.isMonitoring,
    required this.isTriggeringSos,
    required this.sosTriggered,
    required this.expiresAt,
  });

  int get remainingSeconds {
    if (!isMonitoring || expiresAt == null) return intervalMinutes * 60;
    final secs = expiresAt!.difference(DateTime.now()).inSeconds;
    return secs.clamp(0, 99999);
  }

  InternalHeartbeatState copyWith({
    int? intervalMinutes,
    bool? isMonitoring,
    bool? isTriggeringSos,
    bool? sosTriggered,
    Object? expiresAt = _sentinel,
  }) {
    return InternalHeartbeatState(
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      isTriggeringSos: isTriggeringSos ?? this.isTriggeringSos,
      sosTriggered: sosTriggered ?? this.sosTriggered,
      expiresAt: identical(expiresAt, _sentinel)
          ? this.expiresAt
          : expiresAt as DateTime?,
    );
  }

  static const Object _sentinel = Object();
}

class InternalHeartbeatService {
  InternalHeartbeatService._();
  static final InternalHeartbeatService instance = InternalHeartbeatService._();

  static const List<int> intervalOptionsMin = [3, 5, 10, 15];
  static const int _defaultIntervalMin = 3;

  static const String _kInterval = 'heartbeat_interval_min';
  static const String _kMonitoring = 'heartbeat_is_monitoring';
  static const String _kSosTriggered = 'heartbeat_sos_triggered';
  static const String _kExpiresAt = 'heartbeat_expires_at';

  final _controller = StreamController<InternalHeartbeatState>.broadcast();
  Timer? _ticker;
  bool _initialized = false;

  InternalHeartbeatState _state = const InternalHeartbeatState(
    intervalMinutes: _defaultIntervalMin,
    isMonitoring: false,
    isTriggeringSos: false,
    sosTriggered: false,
    expiresAt: null,
  );

  Stream<InternalHeartbeatState> get stream => _controller.stream;
  InternalHeartbeatState get current => _state;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final interval = prefs.getInt(_kInterval) ?? _defaultIntervalMin;
    final monitoring = prefs.getBool(_kMonitoring) ?? false;
    final sos = prefs.getBool(_kSosTriggered) ?? false;
    final expiresRaw = prefs.getString(_kExpiresAt);
    final expiresAt = expiresRaw != null ? DateTime.tryParse(expiresRaw) : null;

    _state = _state.copyWith(
      intervalMinutes: interval,
      isMonitoring: monitoring,
      sosTriggered: sos,
      expiresAt: expiresAt,
    );
    _emit();

    if (_state.isMonitoring) {
      _startTicker();
    }
  }

  Future<void> setIntervalMinutes(int minutes) async {
    if (!intervalOptionsMin.contains(minutes) || _state.isMonitoring) return;
    _state = _state.copyWith(intervalMinutes: minutes);
    await _persist();
    _emit();
  }

  Future<void> startMonitoring() async {
    final expiresAt = DateTime.now().add(
      Duration(minutes: _state.intervalMinutes),
    );
    _state = _state.copyWith(
      isMonitoring: true,
      sosTriggered: false,
      expiresAt: expiresAt,
    );
    await _persist();
    _emit();
    _startTicker();
  }

  Future<void> stopMonitoring() async {
    _ticker?.cancel();
    _ticker = null;
    _state = _state.copyWith(
      isMonitoring: false,
      expiresAt: null,
    );
    await _persist();
    _emit();
  }

  Future<void> checkIn() async {
    if (!_state.isMonitoring || _state.isTriggeringSos) return;
    final expiresAt = DateTime.now().add(
      Duration(minutes: _state.intervalMinutes),
    );
    _state = _state.copyWith(expiresAt: expiresAt);
    await _persist();
    _emit();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_state.isMonitoring || _state.expiresAt == null || _state.isTriggeringSos) {
        return;
      }
      if (DateTime.now().isAfter(_state.expiresAt!)) {
        _onHeartbeatMissed();
      } else {
        _emit();
      }
    });
  }

  Future<void> _onHeartbeatMissed() async {
    if (_state.isTriggeringSos) return;
    _state = _state.copyWith(
      isTriggeringSos: true,
      isMonitoring: false,
    );
    _emit();
    await _persist();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;
      final contacts = await FirestoreService.instance.getEmergencyContacts(uid);
      final pos = await LocationService.instance.getCurrentPosition();
      GeoPoint? geo;
      if (pos != null) {
        geo = GeoPoint(pos.latitude, pos.longitude);
        final profile = await FirestoreService.instance.getUser(uid);
        await FirestoreService.instance.sendBroadcast(
          uid: uid,
          message: 'SOS! Internal heartbeat missed. Immediate assistance needed.',
          alertType: 'need_help',
          location: geo,
          userName: profile?.name,
        );
      }
      await _notifyContactsViaSms(contacts: contacts, location: geo);
      _state = _state.copyWith(sosTriggered: true, expiresAt: null);
    } catch (_) {
      // best-effort
    } finally {
      _state = _state.copyWith(isTriggeringSos: false);
      await _persist();
      _emit();
    }
  }

  Future<void> _notifyContactsViaSms({
    required List<EmergencyContact> contacts,
    GeoPoint? location,
  }) async {
    if (contacts.isEmpty || kIsWeb) return;
    final recipients = contacts
        .map((c) => c.phone.trim())
        .where((p) => p.isNotEmpty)
        .join(',');
    if (recipients.isEmpty) return;

    final locationText = location == null
        ? 'Location unavailable'
        : 'https://maps.google.com/?q=${location.latitude},${location.longitude}';
    final body = Uri.encodeComponent(
      'SAKHI SOS: Heartbeat missed. Please check on me immediately. My location: $locationText',
    );
    final smsUri = 'sms:$recipients?body=$body';
    await launchUrlString(smsUri);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kInterval, _state.intervalMinutes);
    await prefs.setBool(_kMonitoring, _state.isMonitoring);
    await prefs.setBool(_kSosTriggered, _state.sosTriggered);
    if (_state.expiresAt != null) {
      await prefs.setString(_kExpiresAt, _state.expiresAt!.toIso8601String());
    } else {
      await prefs.remove(_kExpiresAt);
    }
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_state);
    }
  }
}
