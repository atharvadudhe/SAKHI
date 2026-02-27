import '../models/user_model.dart';

/// Checks if a user is eligible to be displayed as a volunteer for walking buddy requests
class VolunteerEligibility {
  static const bool _debug = true;

  static void _log(String message) {
    if (_debug) {
      print('👤 [VolunteerEligibility] $message');
    }
  }

  /// Check if a volunteer meets all eligibility criteria
  /// 
  /// A volunteer is eligible if:
  /// - role == "volunteer"
  /// - verificationStatus == "verified"
  /// - isAvailable == true
  /// 
  /// Note: This is a broadcast model. We DON'T filter by volunteerId.
  /// Every request should be visible to EVERY verified, available volunteer.
  static bool isEligibleVolunteer(UserModel volunteer) {
    _log('Checking eligibility for: ${volunteer.name} (${volunteer.uid})');
    _log('  role: ${volunteer.role.name} (expected: volunteer)');
    _log('  verificationStatus: ${volunteer.verificationStatus} (expected: verified)');
    _log('  isAvailable: ${volunteer.isAvailable} (expected: true)');

    if (volunteer.role.name != 'volunteer') {
      _log('  ❌ REJECTED: Not a volunteer');
      return false;
    }

    if (volunteer.verificationStatus != 'verified') {
      _log('  ❌ REJECTED: Not verified (status=${volunteer.verificationStatus})');
      return false;
    }

    if (!volunteer.isAvailable) {
      _log('  ❌ REJECTED: Currently unavailable');
      return false;
    }

    _log('  ✅ ELIGIBLE');
    return true;
  }

  /// Get eligibility status with reason (for UI display)
  static ({bool eligible, String reason}) getEligibilityWithReason(UserModel volunteer) {
    if (volunteer.role.name != 'volunteer') {
      return (eligible: false, reason: 'Not an approved volunteer');
    }

    if (volunteer.verificationStatus != 'verified') {
      return (eligible: false, reason: 'Verification pending or rejected');
    }

    if (!volunteer.isAvailable) {
      return (eligible: false, reason: 'Currently unavailable');
    }

    return (eligible: true, reason: 'Ready to accept requests');
  }
}
