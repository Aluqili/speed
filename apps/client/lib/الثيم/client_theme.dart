import 'package:flutter/material.dart';

/// ألوان وثيم تطبيق العميل - تصميم Glassmorphism برتقالي
class ClientColors {
  static const primary      = Color(0xFFFF6B00);
  static const primaryLight = Color(0xFFFF8E3C);
  static const primaryGlow  = Color(0xFFFFB06A);
  static const accent       = Color(0xFFFFA65A);
  static const background   = Color(0xFF0F0F0F);
  static const surface      = Color(0xFF1A1A1A);
  static const surfaceCard  = Color(0x1AFFFFFF);
  static const glassBorder  = Color(0x4DFF6B00);
  static const textPrimary  = Colors.white;
  static const textSecondary = Color(0xA6FFFFFF);
  static const success      = Color(0xFF00E676);
  static const error        = Color(0xFFFF5252);
  static const warning      = Color(0xFFFFDE59);

  // ألوان الثيم الفاتح
  static const lightBackground   = Color(0xFFFFFFFF);
  static const lightSurface      = Color(0xFFFFFFFF);
  static const lightSurfaceCard  = Color(0xFFFFFFFF);
  static const lightGlassBorder  = Color(0x33FF6B00);
  static const lightTextPrimary  = Color(0xFF1A1A1A);
  static const lightTextSecondary = Color(0xFF6B6B6B);

  static const primaryGradient = LinearGradient(
    colors: [primary, primary],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const warmGradient = LinearGradient(
    colors: [primary, primary],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  // ظل برتقالي
  static List<BoxShadow> glowShadow({double opacity = 0.35, double blur = 20}) => [
    BoxShadow(
      color: primary.withValues(alpha: opacity),
      blurRadius: blur,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> softCardShadow({
    bool dark = false,
    double opacity = 0.08,
    double blur = 18,
    Offset offset = const Offset(0, 8),
  }) =>
      [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? opacity + 0.06 : opacity),
          blurRadius: blur,
          offset: offset,
        ),
      ];
}

class ClientAppTheme {
  static const _fontFamily = 'Cairo';

  // ─── الثيم الفاتح (الافتراضي) ───────────────────────────────────────────
  static ThemeData get light {
    const primary = ClientColors.primary;

    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFE0CC),
      onPrimaryContainer: Color(0xFF4A1800),
      secondary: ClientColors.accent,
      onSecondary: Color(0xFF4A2800),
      secondaryContainer: Color(0xFFFFEFB0),
      onSecondaryContainer: Color(0xFF3A2000),
      tertiary: Color(0xFF00875A),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFB2F0CC),
      onTertiaryContainer: Color(0xFF003D20),
      error: Color(0xFFD32F2F),
      onError: Colors.white,
      errorContainer: Color(0xFFFFCDD2),
      onErrorContainer: Color(0xFF8B0000),
      surface: ClientColors.lightSurface,
      onSurface: ClientColors.lightTextPrimary,
      surfaceContainerHighest: Color(0xFFF0F0F0),
      onSurfaceVariant: ClientColors.lightTextSecondary,
      outline: Color(0xFFDDDDDD),
      outlineVariant: Color(0xFFEEEEEE),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF1A1A1A),
      onInverseSurface: Colors.white,
      inversePrimary: primary,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
      fontFamily: _fontFamily,
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge:   const TextStyle(fontWeight: FontWeight.w900, fontSize: 34, letterSpacing: -0.5, color: ClientColors.lightTextPrimary),
      displayMedium:  const TextStyle(fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.3, color: ClientColors.lightTextPrimary),
      displaySmall:   const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: ClientColors.lightTextPrimary),
      headlineLarge:  const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: ClientColors.lightTextPrimary),
      headlineMedium: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: ClientColors.lightTextPrimary),
      headlineSmall:  const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: ClientColors.lightTextPrimary),
      titleLarge:     const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: ClientColors.lightTextPrimary),
      titleMedium:    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: ClientColors.lightTextPrimary),
      titleSmall:     const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ClientColors.lightTextPrimary),
      bodyLarge:      const TextStyle(fontWeight: FontWeight.w400, fontSize: 16, height: 1.5, color: ClientColors.lightTextPrimary),
      bodyMedium:     const TextStyle(fontWeight: FontWeight.w400, fontSize: 14, height: 1.5, color: ClientColors.lightTextPrimary),
      bodySmall:      const TextStyle(fontWeight: FontWeight.w400, fontSize: 12, height: 1.4, color: ClientColors.lightTextSecondary),
      labelLarge:     const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.1, color: ClientColors.lightTextPrimary),
      labelMedium:    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: ClientColors.lightTextSecondary),
      labelSmall:     const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, letterSpacing: 0.5, color: ClientColors.lightTextSecondary),
    );

    return base.copyWith(
      primaryColor: primary,
      scaffoldBackgroundColor: ClientColors.lightBackground,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      hintColor: const Color(0xFF9E9E9E),
      disabledColor: const Color(0xFFBDBDBD),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x14000000),
        elevation: 0.5,
        centerTitle: true,
        foregroundColor: ClientColors.lightTextPrimary,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: ClientColors.lightTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 3,
        shadowColor: const Color(0x18000000),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ClientColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: ClientColors.lightTextSecondary),
        hintStyle:  const TextStyle(color: Color(0xFF9E9E9E)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: ClientColors.primary,
        unselectedItemColor: Color(0xFF9E9E9E),
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEEEEEE),
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: ClientColors.lightTextPrimary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1A1A),
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: Colors.white,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ─── الثيم الداكن ────────────────────────────────────────────────────────
  static ThemeData get dark {
    const primary = ClientColors.primary;

    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF7A3000),
      onPrimaryContainer: Color(0xFFFFE0CC),
      secondary: ClientColors.accent,
      onSecondary: Color(0xFF5A3000),
      secondaryContainer: Color(0xFF5A3000),
      onSecondaryContainer: Color(0xFFFFE0CC),
      tertiary: ClientColors.success,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF003D20),
      onTertiaryContainer: Color(0xFFB2F0CC),
      error: ClientColors.error,
      onError: Colors.white,
      errorContainer: Color(0xFF8B0000),
      onErrorContainer: Color(0xFFFFCDD2),
      surface: ClientColors.surface,
      onSurface: Colors.white,
      surfaceContainerHighest: Color(0xFF2A2A2A),
      onSurfaceVariant: ClientColors.textSecondary,
      outline: Color(0xFF3A3A3A),
      outlineVariant: Color(0xFF2A2A2A),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Colors.white,
      onInverseSurface: ClientColors.background,
      inversePrimary: primary,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
      fontFamily: _fontFamily,
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge:   const TextStyle(fontWeight: FontWeight.w900, fontSize: 34, letterSpacing: -0.5),
      displayMedium:  const TextStyle(fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.3),
      displaySmall:   const TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
      headlineLarge:  const TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
      headlineMedium: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      headlineSmall:  const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      titleLarge:     const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
      titleMedium:    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      titleSmall:     const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      bodyLarge:      const TextStyle(fontWeight: FontWeight.w400, fontSize: 16, height: 1.5),
      bodyMedium:     const TextStyle(fontWeight: FontWeight.w400, fontSize: 14, height: 1.5),
      bodySmall:      const TextStyle(fontWeight: FontWeight.w400, fontSize: 12, height: 1.4),
      labelLarge:     const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.1),
      labelMedium:    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      labelSmall:     const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, letterSpacing: 0.5),
    ).apply(
      bodyColor:    Colors.white,
      displayColor: Colors.white,
    );

    return base.copyWith(
      primaryColor: primary,
      scaffoldBackgroundColor: ClientColors.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      hintColor: const Color(0xFF636366),
      disabledColor: const Color(0xFF48484A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: ClientColors.surfaceCard,
        elevation: 2,
        shadowColor: const Color(0x33000000),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ClientColors.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ClientColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ClientColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: ClientColors.textSecondary),
        hintStyle:  const TextStyle(color: ClientColors.textSecondary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: ClientColors.primary,
        unselectedItemColor: Color(0xFF636366),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A2A),
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ClientColors.surface,
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: Colors.white,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
