import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'firestore_service.dart';

/// Tamper-proof evidence vault.
///
/// During an SOS session this service:
/// 1. Starts a covert background audio recording.
/// 2. On stop, reads the file bytes and computes a SHA-256 hash.
/// 3. Uploads the recording to Firebase Storage.
/// 4. Persists the hash, download URL, and timestamps to Firestore's
///    `session_evidence` collection for legal integrity.
class EvidenceService {
  EvidenceService._();
  static final EvidenceService instance = EvidenceService._();

  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _filePath;

  /// Whether a recording is in progress.
  bool get isRecording => _isRecording;

  // ───────── Start Recording ─────────

  /// Begin covert audio recording. Returns `true` if recording started
  /// successfully. Silently returns `false` on permission denial or
  /// unsupported platforms to avoid blocking the SOS flow.
  Future<bool> startCovertRecording(String sessionId) async {
    if (_isRecording) return true; // already recording

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        debugPrint('[EvidenceService] Microphone permission denied.');
        return false;
      }

      // Build a platform-appropriate temp file path.
      _filePath = await _buildFilePath(sessionId);

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _filePath!,
      );

      _isRecording = true;
      debugPrint('[EvidenceService] Recording started for session $sessionId');
      return true;
    } catch (e) {
      debugPrint('[EvidenceService] Could not start recording: $e');
      return false;
    }
  }

  // ───────── Stop, Hash & Upload ─────────

  /// Stops the recording, hashes the file with SHA-256, uploads it to
  /// Firebase Storage, and saves metadata to Firestore.
  ///
  /// Returns the SHA-256 hex digest on success, or `null` on failure.
  Future<String?> stopAndUploadEvidence(String sessionId) async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder.stop();
      _isRecording = false;

      if (path == null || path.isEmpty) {
        debugPrint('[EvidenceService] No recording file produced.');
        return null;
      }

      // Read bytes.
      final Uint8List bytes;
      if (kIsWeb) {
        // On web, `path` is a blob URL — this branch is a safeguard;
        // web recording support varies by browser.
        debugPrint('[EvidenceService] Web evidence upload not supported.');
        return null;
      } else {
        final file = File(path);
        if (!file.existsSync()) {
          debugPrint('[EvidenceService] Recording file missing: $path');
          return null;
        }
        bytes = await file.readAsBytes();
      }

      // SHA-256 hash.
      final digest = sha256.convert(bytes);
      final hashHex = digest.toString();

      // Upload to Firebase Storage.
      final storagePath = 'evidence/$sessionId/audio.m4a';
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'audio/mp4'),
      );
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Persist metadata in Firestore.
      await FirestoreService.instance.saveSessionEvidence(
        sessionId: sessionId,
        downloadUrl: downloadUrl,
        sha256Hash: hashHex,
        recordedAt: DateTime.now(),
      );

      debugPrint(
        '[EvidenceService] Evidence uploaded. SHA-256: $hashHex',
      );

      // Clean up local file.
      try {
        if (!kIsWeb) File(path).deleteSync();
      } catch (_) {}

      return hashHex;
    } catch (e) {
      debugPrint('[EvidenceService] Stop/upload failed: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel any in-progress recording without uploading.
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    try {
      await _recorder.stop();
    } catch (_) {}
    _isRecording = false;
  }

  /// Dispose the recorder when the app shuts down.
  Future<void> dispose() async {
    await cancelRecording();
    _recorder.dispose();
  }

  // ───────── Helpers ─────────

  Future<String> _buildFilePath(String sessionId) async {
    if (kIsWeb) return '';
    // Use system temp directory.
    final dir = Directory.systemTemp;
    return '${dir.path}/sakhi_evidence_$sessionId.m4a';
  }
}
