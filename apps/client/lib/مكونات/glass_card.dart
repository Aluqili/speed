import 'dart:ui';
import 'package:flutter/material.dart';
import '../الثيم/client_theme.dart';

/// بطاقة زجاجية بتأثير Glassmorphism
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blurSigma = 12,
    this.glassOpacity = 0.10,
    this.showBorder = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final double glassOpacity;
  final bool showBorder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);
    Widget card = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: glassOpacity),
            borderRadius: radius,
            border: showBorder
                ? Border.all(color: ClientColors.glassBorder, width: 1.2)
                : null,
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

/// بطاقة زجاجية مع ظل برتقالي توهجي
class GlowGlassCard extends StatelessWidget {
  const GlowGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: ClientColors.glowShadow(opacity: 0.20, blur: 24),
      ),
      child: GlassCard(
        padding: padding,
        borderRadius: radius,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
