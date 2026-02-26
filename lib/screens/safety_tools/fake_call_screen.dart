import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import '../../config/theme.dart'; // Assuming this has SakhiTheme

/// Mimics an incoming phone call UI to help users de-escalate
/// uncomfortable or dangerous situations.
class FakeCallScreen extends StatefulWidget {
  final String callerName;
  final String callerLabel;

  const FakeCallScreen({
    super.key,
    this.callerName = 'Mom',
    this.callerLabel = 'Mobile',
  });

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  bool _answered = false;
  Timer? _callTimer;
  int _callDurationSec = 0;

  @override
  void initState() {
    super.initState();
    
    // Set status bar to transparent for full-screen call feel
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Begin playing the system ringtone
    _startRinging();
  }

  // ── Audio ──

  void _startRinging() {
    try {
      FlutterRingtonePlayer().play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.electronic,
        looping: true,
        volume: 0.8,
      );
    } catch (e) {
      debugPrint('Ringtone playback failed: $e');
    }
    HapticFeedback.heavyImpact();
  }

  void _stopRinging() {
    try {
      FlutterRingtonePlayer().stop();
    } catch (e) {
      debugPrint('Ringtone stop failed: $e');
    }
  }

  // ── Call Actions ──

  void _acceptCall() {
    _stopRinging();
    HapticFeedback.mediumImpact();
    setState(() => _answered = true);
    _pulseController.stop();

    // Start call-duration counter
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDurationSec++);
    });
  }

  void _declineCall() {
    _stopRinging();
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  void _endCall() {
    _stopRinging();
    _callTimer?.cancel();
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  String get _formattedDuration {
    final min = (_callDurationSec ~/ 60).toString().padLeft(2, '0');
    final sec = (_callDurationSec % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  void dispose() {
    _stopRinging();
    _callTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Realistic Android dialer background gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2C3238), // Dark grey-blue
              Color(0xFF121416), // Almost black
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Caller Info Section
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _answered ? 180 : 250, // Shrinks when answered
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _answered
                          ? const AlwaysStoppedAnimation(1.0)
                          : _pulseAnim,
                      child: CircleAvatar(
                        radius: _answered ? 45 : 60,
                        backgroundColor:
                            SakhiTheme.primary.withValues(alpha: 0.2),
                        child: Text(
                          widget.callerName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: _answered ? 36 : 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.callerName,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _answered ? _formattedDuration : widget.callerLabel,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // In-call actions or Incoming status
              if (_answered) ...[
                // Active Call Grid (Mute, Keypad, Speaker, etc.)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 30,
                    crossAxisSpacing: 20,
                    children: const [
                      _DummyInCallButton(icon: Icons.mic_off_outlined, label: 'Mute'),
                      _DummyInCallButton(icon: Icons.dialpad, label: 'Keypad'),
                      _DummyInCallButton(icon: Icons.volume_up_outlined, label: 'Speaker'),
                      _DummyInCallButton(icon: Icons.add_call, label: 'Add call'),
                      _DummyInCallButton(icon: Icons.pause, label: 'Hold'),
                      _DummyInCallButton(icon: Icons.person_add_alt_1, label: 'Contacts'),
                    ],
                  ),
                ),
                const Spacer(),
              ] else ...[
                // Incoming Call Text
                Text(
                  'Incoming call',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Spacer(),
              ],

              // Bottom Action Buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 60, left: 48, right: 48),
                child: _answered
                    ? _CallActionButton(
                        icon: Icons.call_end_rounded,
                        color: SakhiTheme.danger,
                        onTap: _endCall,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _CallActionButton(
                            icon: Icons.call_end_rounded,
                            color: SakhiTheme.danger,
                            onTap: _declineCall,
                          ),
                          _CallActionButton(
                            icon: Icons.call_rounded,
                            color: SakhiTheme.safe,
                            onTap: _acceptCall,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Circular Call Action Button (Accept/Decline/End) ──

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      color: color,
      elevation: 6,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          // Pulse effect around the button can also be added here later
          child: Icon(icon, color: Colors.white, size: 36),
        ),
      ),
    );
  }
}

// ── Dummy In-Call Grid Buttons ──

class _DummyInCallButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DummyInCallButton({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}