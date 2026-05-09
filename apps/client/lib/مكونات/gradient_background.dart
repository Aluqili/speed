import 'package:flutter/material.dart';
import '../الثيم/client_theme.dart';

/// خلفية تتكيف مع الثيم: داكنة مع دوائر توهج برتقالية، أو فاتحة نظيفة
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      return Container(
        color: ClientColors.lightBackground,
        child: child,
      );
    }
    return Stack(
      children: [
        Container(color: ClientColors.background),
        const Positioned(
          top: -120, right: -80,
          child: _GlowOrb(color: ClientColors.primary, size: 340),
        ),
        const Positioned(
          bottom: 60, left: -100,
          child: _GlowOrb(color: ClientColors.primaryLight, size: 260),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.22), Colors.transparent],
        ),
      ),
    );
  }
}
