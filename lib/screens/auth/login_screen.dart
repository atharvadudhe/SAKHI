import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../config/theme.dart';
import '../../widgets/sakhi_brand_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  final String _countryCode = '+91';
  String? _phoneError;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final phoneInput = _phoneController.text.trim();
    if (phoneInput.length != 10) {
      _triggerPhoneError('Enter a valid 10-digit number');
      return;
    }

    setState(() => _isLoading = true);

    final phoneNumber = '$_countryCode$phoneInput';

    try {
      await AuthService.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) {
          setState(() => _isLoading = false);
          context.push(
            '/otp',
            extra: {
              'verificationId': verificationId,
              'phoneNumber': phoneNumber,
            },
          );
        },
        onError: (error) {
          setState(() => _isLoading = false);
          _showError(error);
        },
        onAutoVerified: (credential) async {
          // Auto-verified: sign in directly with the credential
          try {
            await AuthService.instance.signInWithCredential(credential);
            if (!mounted) return;
            // Check if profile exists and navigate accordingly
            final hasProfile = await AuthService.instance.hasProfile();
            if (!mounted) return;
            setState(() => _isLoading = false);
            if (hasProfile) {
              context.go('/home');
            } else {
              context.go('/profile-setup');
            }
          } catch (e) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            _showError(e.toString());
          }
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  void _triggerPhoneError(String message) {
    setState(() {
      _phoneError = message;
    });
    HapticFeedback.vibrate();
    _shakeController.forward(from: 0);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: SakhiTheme.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo
                          const Center(
                            child: SakhiBrandLogo(size: 86, elevated: true),
                          ),
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              'SAKHI',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 8,
                                color: SakhiTheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),
                          // Welcome text
                          Text(
                            'Welcome',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter your phone number to get started with your safety companion.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                          ),
                          const SizedBox(height: 32),
                          // Phone number input
                          Text(
                            'Phone Number',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          AnimatedBuilder(
                            animation: _shakeController,
                            builder: (context, child) {
                              final value = _shakeController.value;
                              final dx =
                                  math.sin(value * math.pi * 8) *
                                  (1 - value) *
                                  12;
                              return Transform.translate(
                                offset: Offset(dx, 0),
                                child: child,
                              );
                            },
                            child: Row(
                              children: [
                                // Country code
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _phoneError == null
                                          ? Colors.grey.shade300
                                          : SakhiTheme.danger,
                                    ),
                                  ),
                                  child: Text(
                                    _countryCode,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Phone field
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: 'Enter phone number',
                                      errorText: null,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _phoneError == null
                                              ? Colors.grey.shade300
                                              : SakhiTheme.danger,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _phoneError == null
                                              ? SakhiTheme.primary
                                              : SakhiTheme.danger,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onChanged: (_) {
                                      if (_phoneError != null) {
                                        setState(() => _phoneError = null);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            child: _phoneError == null
                                ? const SizedBox(height: 0)
                                : Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8,
                                      left: 2,
                                    ),
                                    child: Text(
                                      _phoneError!,
                                      style: const TextStyle(
                                        color: SakhiTheme.danger,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 32),
                          // Continue button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _sendOTP,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SakhiTheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Continue'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
