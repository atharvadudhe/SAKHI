import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SOSButton extends StatefulWidget {
  final VoidCallback onTriggered;
  final double size;

  const SOSButton({super.key, required this.onTriggered, this.size = 72});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _isLongPressing = false;
  double _holdProgress = 0;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isLongPressing = true;
      _holdProgress = 0;
    });

    const updateInterval = Duration(milliseconds: 50);
    const holdDuration = Duration(milliseconds: 1500);
    final totalTicks =
        holdDuration.inMilliseconds ~/ updateInterval.inMilliseconds;
    int ticks = 0;

    _holdTimer = Timer.periodic(updateInterval, (timer) {
      ticks++;
      setState(() {
        _holdProgress = ticks / totalTicks;
      });

      if (ticks >= totalTicks) {
        timer.cancel();
        HapticFeedback.heavyImpact();
        widget.onTriggered();
        setState(() {
          _isLongPressing = false;
          _holdProgress = 0;
        });
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    setState(() {
      _isLongPressing = false;
      _holdProgress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _isLongPressing
          ? AlwaysStoppedAnimation(1.0 + _holdProgress * 0.15)
          : _pulseAnimation,
      child: GestureDetector(
        onLongPressStart: (_) => _startHold(),
        onLongPressEnd: (_) => _cancelHold(),
        onLongPressCancel: _cancelHold,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring
            Container(
              width: widget.size + 24,
              height: widget.size + 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.15),
              ),
            ),
            // Progress ring
            if (_isLongPressing)
              SizedBox(
                width: widget.size + 16,
                height: widget.size + 16,
                child: CircularProgressIndicator(
                  value: _holdProgress,
                  strokeWidth: 4,
                  color: Colors.white,
                  backgroundColor: Colors.red.shade200,
                ),
              ),
            // Main button
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.red.shade600, Colors.red.shade900],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.5),
                    blurRadius: _isLongPressing ? 24 : 12,
                    spreadRadius: _isLongPressing ? 4 : 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.size * 0.2,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
