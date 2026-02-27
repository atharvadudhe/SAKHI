import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/platform_helper.dart';
import '../models/user_model.dart';
import '../widgets/animated_gradient_bg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _scaleController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _scaleController.forward();

    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    try {
      // On Web/Desktop, if admin override is still active, go straight to admin.
      if (isWebOrDesktop && AuthService.instance.isAdminOverrideActive) {
        if (mounted) context.go('/admin');
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final hasProfile = await AuthService.instance.hasProfile();
        if (!mounted) return;
        if (!hasProfile) {
          context.go('/profile-setup');
          return;
        }
        // Fetch role and redirect accordingly
        final userModel = await FirestoreService.instance.getUser(user.uid);
        if (!mounted) return;
        switch (userModel?.role ?? UserRole.user) {
          case UserRole.admin:
            if (kIsWeb) {
              context.go('/admin');
            } else {
              // Admin cannot access from mobile — sign out
              await AuthService.instance.signOut();
              if (mounted) context.go('/login');
            }
          case UserRole.volunteer:
            // Volunteer and user both land on the same home dashboard
            // with tabs (user sees default, volunteer sees requests tab)
            context.go('/home');
          case UserRole.user:
            context.go('/home');
        }
      } else {
        // On Web/Desktop, go directly to email login (admin portal).
        if (isWebOrDesktop) {
          if (mounted) context.go('/email-login');
        } else {
          if (mounted) context.go('/login');
        }
      }
    } catch (e) {
      // Firebase not configured – go to login
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/sakhi-logo-3.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Title
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFFE91E63),
                          Color(0xFFFF6090),
                          Color(0xFFF48FB1),
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'SAKHI',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'सखी',
                      style: TextStyle(
                        fontSize: 22,
                        letterSpacing: 6,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Trusted Friend & Protector',
                      style: TextStyle(
                        fontSize: 14,
                        letterSpacing: 3,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
