import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SOSButton extends StatefulWidget {
  final VoidCallback onTriggered;
  final VoidCallback onCancelTriggered;
  final double size;
  final bool isActive;
  final DateTime? cooldownUntil;

  const SOSButton({
    super.key,
    required this.onTriggered,
    required this.onCancelTriggered,
    this.size = 72,
    this.isActive = false,
    this.cooldownUntil,
  });

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
  Timer? _cooldownTimer;
  Duration _cooldownLeft = Duration.zero;

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
    _initCooldownTicker();
  }

  @override
  void didUpdateWidget(covariant SOSButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cooldownUntil != widget.cooldownUntil) {
      _initCooldownTicker();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _holdTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _initCooldownTicker() {
    _cooldownTimer?.cancel();
    _syncCooldownLeft();
    if (_cooldownLeft > Duration.zero) {
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _syncCooldownLeft();
      });
    }
  }

  void _syncCooldownLeft() {
    final until = widget.cooldownUntil;
    if (until == null) {
      if (mounted) setState(() => _cooldownLeft = Duration.zero);
      return;
    }
    final left = until.difference(DateTime.now());
    if (mounted) {
      setState(() {
        _cooldownLeft = left.isNegative ? Duration.zero : left;
      });
    }
  }

  bool get _isCooldown => _cooldownLeft > Duration.zero && !widget.isActive;

  String get _cooldownLabel {
    final total = _cooldownLeft.inSeconds.clamp(0, 3599);
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
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
        if (widget.isActive) {
          widget.onCancelTriggered();
        } else if (!_isCooldown) {
          widget.onTriggered();
        }
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
    final isEnabled = !widget.isActive && !_isCooldown;
    final canHold = isEnabled || widget.isActive;
    return ScaleTransition(
      scale: !isEnabled
          ? const AlwaysStoppedAnimation(1.0)
          : _isLongPressing
          ? AlwaysStoppedAnimation(1.0 + _holdProgress * 0.15)
          : _pulseAnimation,
      child: GestureDetector(
        onLongPressStart: canHold ? (_) => _startHold() : null,
        onLongPressEnd: canHold ? (_) => _cancelHold() : null,
        onLongPressCancel: canHold ? _cancelHold : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring
            Container(
              width: widget.size + 24,
              height: widget.size + 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isActive
                    ? Colors.red.withValues(alpha: 0.14)
                    : Colors.red.withValues(alpha: isEnabled ? 0.15 : 0.06),
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
                  colors: widget.isActive
                      ? [Colors.red.shade500, Colors.red.shade800]
                      : isEnabled
                      ? [Colors.red.shade600, Colors.red.shade900]
                      : [Colors.red.shade300, Colors.red.shade400],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: isEnabled ? 0.5 : 0.18),
                    blurRadius: _isLongPressing ? 24 : 12,
                    spreadRadius: _isLongPressing ? 4 : 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isActive ? Icons.close_rounded : Icons.warning_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.isActive
                        ? 'HOLD'
                        : _isCooldown
                        ? _cooldownLabel
                        : 'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _isCooldown ? widget.size * 0.17 : widget.size * 0.2,
                      fontWeight: FontWeight.w900,
                      letterSpacing: _isCooldown ? 1 : 2,
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
