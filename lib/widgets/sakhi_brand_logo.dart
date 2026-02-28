import 'package:flutter/material.dart';

class SakhiBrandLogo extends StatelessWidget {
  final double size;
  final bool withAura;
  final bool elevated;
  final bool framed;

  const SakhiBrandLogo({
    super.key,
    this.size = 80,
    this.withAura = false,
    this.elevated = false,
    this.framed = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(size * 0.24);
    final outerShadow = [
      if (withAura)
        BoxShadow(
          color: const Color(0xFFE91E63).withValues(alpha: 0.24),
          blurRadius: size * 0.32,
          spreadRadius: size * 0.04,
        ),
      if (elevated)
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
    ];

    if (!framed) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: outerShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.2),
          child: Image.asset(
            'assets/images/sakhi-logo-3.png',
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: withAura ? outerShadow.take(1).toList() : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
          border: Border.all(
            color: const Color(0xFFF8BBD0).withValues(alpha: 0.7),
            width: 1,
          ),
          boxShadow: elevated
              ? outerShadow.skip(withAura ? 1 : 0).toList()
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.2),
          child: Image.asset(
            'assets/images/sakhi-logo-3.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
