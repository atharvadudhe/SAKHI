import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/constants.dart';
import '../models/user_model.dart';
import 'platform_helper.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Tracks whether the admin is authenticated via hardcoded credentials
  /// (Web/Desktop only — no Firebase Auth session exists).
  bool _isAdminOverrideActive = false;
  bool get isAdminOverrideActive => _isAdminOverrideActive;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null || _isAdminOverrideActive;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Send OTP to the given phone number
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: onAutoVerified,
        verificationFailed: (e) => onError(e.message ?? 'Verification failed'),
        codeSent: (verificationId, resendToken) => onCodeSent(verificationId),
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  /// Verify OTP code
  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );

    final cred = await _auth.signInWithCredential(credential);
    await _syncFcmTokenForUser(cred.user!.uid);
    return cred;
  }

  /// Sign in with credential (used for auto-verification)
  Future<UserCredential> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    final cred = await _auth.signInWithCredential(credential);
    if (cred.user != null) {
      await _syncFcmTokenForUser(cred.user!.uid);
    }
    return cred;
  }

  // ── Email / Password Auth ──────────────────────────────────────────────

  /// Register a new user with email and password
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // ── Predefined Admin Credentials (Web / Desktop only) ─────────────
  static const String _adminEmail = 'admin@sakhi.com';
  static const String _adminPassword = 'Admin@123';

  /// Returns `true` when the supplied credentials match the hardcoded admin
  /// account.  Only meaningful on Web / Desktop where standard user login is
  /// blocked.
  bool validateAdminCredentials({
    required String email,
    required String password,
  }) {
    return email == _adminEmail && password == _adminPassword;
  }

  /// Sign in with email and password.
  ///
  /// On **Web / Desktop** the method enforces the predefined admin
  /// credentials.  It validates locally first, then signs in via Firebase
  /// Auth so that a real user session exists (needed for Firestore rules).
  /// If the admin account doesn't exist in Firebase Auth yet it is created
  /// automatically together with a Firestore admin profile.
  ///
  /// On **Mobile** it delegates to the standard Firebase
  /// `signInWithEmailAndPassword` flow.
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (isWebOrDesktop) {
      if (!validateAdminCredentials(email: email, password: password)) {
        throw FirebaseAuthException(
          code: 'admin-only',
          message:
              'Access Denied: Standard user login is restricted on Desktop/Web.',
        );
      }

      // Credentials match — get a real Firebase Auth session so Firestore
      // security rules will recognise the request.
      _isAdminOverrideActive = true;

      UserCredential cred;
      try {
        cred = await _auth.signInWithEmailAndPassword(
          email: _adminEmail,
          password: _adminPassword,
        );
      } on FirebaseAuthException catch (_) {
        // Firebase Auth user doesn't exist yet → create it once.
        cred = await _auth.createUserWithEmailAndPassword(
          email: _adminEmail,
          password: _adminPassword,
        );
      } catch (e) {
        // `firebase_auth` throws its own FirebaseAuthException. Since we
        // declared a local class with the same name, catch broadly and
        // check the error message for "user-not-found" to disambiguate.
        final msg = e.toString();
        if (msg.contains('user-not-found') ||
            msg.contains('INVALID_LOGIN_CREDENTIALS') ||
            msg.contains('invalid-credential')) {
          cred = await _auth.createUserWithEmailAndPassword(
            email: _adminEmail,
            password: _adminPassword,
          );
        } else {
          rethrow;
        }
      }

      // Ensure a Firestore admin profile doc exists.
      final uid = cred.user!.uid;
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();
      if (!doc.exists) {
        final adminModel = UserModel(
          uid: uid,
          name: 'Admin',
          phone: '',
          role: UserRole.admin,
        );
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .set(adminModel.toJson());
      } else if (doc.data()?['role'] != 'admin') {
        // Profile exists but role is wrong — promote to admin.
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .update({'role': 'admin'});
      }

      await _syncFcmTokenForUser(uid);
      return cred;
    }

    // ── Mobile: normal Firebase flow ──
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _syncFcmTokenForUser(cred.user!.uid);
    return cred;
  }

  Future<void> _syncFcmTokenForUser(String uid) async {
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
      debugPrint("FCM token saved for user: $uid");
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set({'fcmToken': newToken}, SetOptions(merge: true));
      debugPrint("FCM token refreshed for user: $uid");
    });
  }

  /// Check if user profile exists in Firestore
  /// Retries up to [maxRetries] times with exponential backoff on transient
  /// Firestore errors (e.g. unavailable).
  Future<bool> hasProfile({int maxRetries = 3}) async {
    // Capture a stable reference — currentUser can become null during retries
    // if the user signs out concurrently.
    final user = currentUser;
    if (user == null) return false;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final doc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .get(const GetOptions(source: Source.server));
        return doc.exists;
      } on FirebaseException catch (e) {
        // Retry on transient errors (unavailable / deadline-exceeded)
        final retryable =
            e.code == 'unavailable' || e.code == 'deadline-exceeded';
        if (!retryable || attempt == maxRetries) rethrow;
        // Exponential backoff: 1s, 2s, 4s …
        await Future.delayed(Duration(seconds: 1 << attempt));
      }
    }
    return false; // unreachable, but satisfies return type
  }

  /// Create user profile after first login.
  /// Times out after [timeoutSeconds] to avoid hanging when Firestore is
  /// unreachable.
  Future<void> createProfile({
    required String name,
    required UserRole role,
    String? photoUrl,
    int timeoutSeconds = 15,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');

    final userModel = UserModel(
      uid: user.uid,
      name: name,
      phone: user.phoneNumber ?? '',
      role: role,
      photoUrl: photoUrl,
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(userModel.toJson())
        .timeout(
          Duration(seconds: timeoutSeconds),
          onTimeout: () => throw Exception(
            'Firestore is not responding. Please check your internet '
            'connection and ensure the Firestore database has been created '
            'in the Firebase Console.',
          ),
        );
  }

  /// Sign out
  Future<void> signOut() async {
    _isAdminOverrideActive = false;
    await _auth.signOut();
  }
}

/// Custom exception used when non-admin credentials are supplied on
/// Web / Desktop.
class FirebaseAuthException implements Exception {
  final String code;
  final String message;
  const FirebaseAuthException({required this.code, required this.message});

  @override
  String toString() => message;
}
