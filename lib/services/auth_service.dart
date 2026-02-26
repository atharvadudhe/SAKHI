import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/constants.dart';
import '../models/user_model.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
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
    return await _auth.signInWithCredential(credential);
  }

  /// Sign in with credential (used for auto-verification)
  Future<UserCredential> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    return await _auth.signInWithCredential(credential);
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

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Check if user profile exists in Firestore
  /// Retries up to [maxRetries] times with exponential backoff on transient
  /// Firestore errors (e.g. unavailable).
  Future<bool> hasProfile({int maxRetries = 3}) async {
    if (currentUser == null) return false;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final doc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(currentUser!.uid)
            .get(const GetOptions(source: Source.server));
        return doc.exists;
      } on FirebaseException catch (e) {
        // Retry on transient errors (unavailable / deadline-exceeded)
        final retryable = e.code == 'unavailable' ||
            e.code == 'deadline-exceeded';
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
    int timeoutSeconds = 15,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');

    final userModel = UserModel(
      uid: user.uid,
      name: name,
      phone: user.phoneNumber ?? '',
      role: role,
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
    await _auth.signOut();
  }
}
