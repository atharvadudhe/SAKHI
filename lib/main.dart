import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAKHI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E63),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ─── Animated floating particle ───
class _Particle {
  double x, y, radius, speed, opacity;
  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.opacity,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _pulseController;
  late final AnimationController _fadeController;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _fadeAnim;
  final List<_Particle> _particles = [];
  final math.Random _rand = math.Random();

  @override
  void initState() {
    super.initState();

    // Background gradient rotation
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Pulse animation for the title
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Fade-in on launch
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    // Generate floating particles
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle(
        x: _rand.nextDouble(),
        y: _rand.nextDouble(),
        radius: _rand.nextDouble() * 3 + 1,
        speed: _rand.nextDouble() * 0.0004 + 0.0001,
        opacity: _rand.nextDouble() * 0.4 + 0.1,
      ));
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Stack(
            children: [
              // ── Animated gradient background ──
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(
                      math.cos(_bgController.value * 2 * math.pi),
                      math.sin(_bgController.value * 2 * math.pi),
                    ),
                    end: Alignment(
                      -math.cos(_bgController.value * 2 * math.pi),
                      -math.sin(_bgController.value * 2 * math.pi),
                    ),
                    colors: const [
                      Color(0xFF1A0A2E),
                      Color(0xFF16213E),
                      Color(0xFF0F3460),
                      Color(0xFF1A0A2E),
                    ],
                  ),
                ),
              ),

              // ── Floating particles ──
              ...List.generate(_particles.length, (i) {
                final p = _particles[i];
                final dy = ((_bgController.value * p.speed * 10000) % 1.0);
                final top = ((p.y + dy) % 1.0) *
                    MediaQuery.of(context).size.height;
                final left = p.x * MediaQuery.of(context).size.width;
                return Positioned(
                  top: top,
                  left: left,
                  child: Container(
                    width: p.radius * 2,
                    height: p.radius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: p.opacity),
                    ),
                  ),
                );
              }),

              // ── Main content ──
              FadeTransition(
                opacity: _fadeAnim,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glowing ring behind logo
                      ScaleTransition(
                        scale: _pulseAnim,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0x55E91E63),
                                Color(0x00E91E63),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFFE91E63).withValues(alpha: 0.3),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE91E63)
                                      .withValues(alpha: 0.6),
                                  width: 2,
                                ),
                                gradient: const RadialGradient(
                                  colors: [
                                    Color(0x33E91E63),
                                    Color(0x11E91E63),
                                  ],
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.favorite_rounded,
                                  size: 48,
                                  color: Color(0xFFE91E63),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── "SAKHI" title ──
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFE91E63),
                            Color(0xFFFF6090),
                            Color(0xFFF48FB1),
                            Color(0xFFE91E63),
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          'SAKHI',
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 16,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Tagline
                      Text(
                        'Your Trusted Companion',
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 4,
                          color: Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
