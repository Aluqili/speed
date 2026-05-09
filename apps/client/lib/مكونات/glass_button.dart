import 'package:flutter/material.dart';
import '../الثيم/client_theme.dart';

/// زر متدرج برتقالي مع توهج (Glow Button)
class GlowButton extends StatelessWidget {
  const GlowButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.small = false,
    this.fullWidth = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool small;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final height = small ? 42.0 : 52.0;
    final fontSize = small ? 13.0 : 15.0;

    Widget button = Container(
      height: height,
      width: fullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: ClientColors.primaryGradient,
        boxShadow: ClientColors.glowShadow(opacity: 0.40, blur: 22),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.15),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: small ? 16 : 24),
            child: Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: small ? 16 : 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return button;
  }
}

/// زر ثانوي شفاف بحدود برتقالية
class OutlineGlassButton extends StatelessWidget {
  const OutlineGlassButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.small = false,
    this.fullWidth = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool small;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: small ? 42.0 : 52.0,
        width: fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: small ? 16 : 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ClientColors.primary, width: 1.5),
          color: ClientColors.primary.withValues(alpha: 0.10),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: ClientColors.primary, size: small ? 16 : 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: ClientColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: small ? 13.0 : 15.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
