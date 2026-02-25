import 'package:flutter/material.dart';

/// ثيم التطبيق: ألوان وخطوط وإعدادات عامة.
class AppThemeArabic {
  static const Color clientPrimary = Color(0xFFE85D2A);
  static const Color clientAccent = Color(0xFFFFC145);
  static const Color clientBackground = Color(0xFFFFF8F3);
  static const Color clientSurface = Color(0xFFFFFCFA);
  static const Color clientTextPrimary = Color(0xFF1F2937);
  static const Color clientTextSecondary = Color(0xFF64748B);
  static const Color clientSuccess = Color(0xFF22C55E);
  static const Color clientError = Color(0xFFEF4444);
  static const Color _clientSeed = clientPrimary;

  /// إنشاء ثيم من لون أساسي (seed)
  static ThemeData fromSeed(Color seed, {bool dark = false}) => _buildCommon(seed, dark: dark);
  /// بناء ثيم مشترك مع لون أساسي مخصّص + دعم الوضع الداكن ونصوص عربية واضحة
  static ThemeData _buildCommon(Color seed, {bool dark = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: dark ? Brightness.dark : Brightness.light,
      fontFamily: 'Cairo',
    );
    final textTheme = base.textTheme.copyWith(
      headlineSmall: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      titleMedium: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      bodyMedium: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
      labelLarge: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
    final readableTextTheme = textTheme.apply(
      bodyColor: dark ? const Color(0xFFE5E7EB) : clientTextPrimary,
      displayColor: dark ? const Color(0xFFF3F4F6) : clientTextPrimary,
    );
    return base.copyWith(
      primaryColor: seed,
      textTheme: readableTextTheme,
      primaryTextTheme: readableTextTheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF121212) : clientBackground,
      hintColor: dark ? const Color(0xFF9CA3AF) : clientTextSecondary,
      disabledColor: dark ? const Color(0xFF6B7280) : const Color(0xFF94A3B8),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? scheme.surface : clientSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        iconTheme: IconThemeData(color: scheme.primary),
        titleTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ).copyWith(color: scheme.primary),
      ),
      // تخصيصات إضافية للمكوّنات
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: readableTextTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: dark ? 0 : 2,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 32,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: readableTextTheme.titleLarge?.copyWith(color: scheme.onSurface),
        contentTextStyle: readableTextTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.onInverseSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: readableTextTheme.bodySmall?.copyWith(color: scheme.inverseSurface),
        preferBelow: false,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(12),
        thumbColor: WidgetStatePropertyAll(scheme.primaryContainer),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: dark ? 0 : 2,
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: readableTextTheme.titleMedium,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: readableTextTheme.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: scheme.primary),
          textStyle: readableTextTheme.titleMedium,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFDFC),
        labelStyle: TextStyle(color: dark ? const Color(0xFFD1D5DB) : clientTextSecondary),
        hintStyle: TextStyle(color: dark ? const Color(0xFF9CA3AF) : clientTextSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selectedColor: scheme.primaryContainer,
        labelStyle: readableTextTheme.bodyMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFCFA),
        labelTextStyle: WidgetStatePropertyAll(readableTextTheme.bodySmall),
        indicatorColor: scheme.primaryContainer,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  /// ثيم افتراضي (عميل)
  static final ThemeData themeData = _buildCommon(_clientSeed);

  /// ثيم تطبيق العميل (فاتح/داكن)
  static final ThemeData clientTheme = _buildCommon(_clientSeed);
  static final ThemeData clientDarkTheme = _buildCommon(_clientSeed, dark: true);

  /// ثيم تطبيق المندوب (فاتح/داكن)
  static final ThemeData courierTheme = _buildCommon(_clientSeed);
  static final ThemeData courierDarkTheme = _buildCommon(_clientSeed, dark: true);

  /// ثيم تطبيق المتجر (فاتح/داكن)
  static final ThemeData storeTheme = _buildCommon(_clientSeed);
  static final ThemeData storeDarkTheme = _buildCommon(_clientSeed, dark: true);
}
