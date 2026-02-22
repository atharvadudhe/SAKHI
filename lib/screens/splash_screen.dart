import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final hasProfile = await AuthService.instance.hasProfile();
        if (mounted) {
          context.go(hasProfile ? '/home' : '/profile-setup');
        }
      } else {
        if (mounted) context.go('/login');
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
                    // Logo ring
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE91E63).withValues(alpha: 0.6),
                          width: 2,
                        ),
                        gradient: const RadialGradient(
                          colors: [Color(0x33E91E63), Color(0x11E91E63)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFE91E63,
                            ).withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.shield_rounded,
                          size: 48,
                          color: Color(0xFFE91E63),
                        ),
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
                    const SizedBox(height: 8),
                    Text(
                      'Your Trusted Companion',
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
