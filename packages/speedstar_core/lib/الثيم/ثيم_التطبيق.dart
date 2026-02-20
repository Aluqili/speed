import 'package:flutter/material.dart';

/// ثيم التطبيق: ألوان وخطوط وإعدادات عامة.
class AppThemeArabic {
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
    return base.copyWith(
      primaryColor: seed,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? scheme.surface : Colors.white,
        elevation: 1,
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
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: dark ? 0 : 1,
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
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
        textStyle: textTheme.bodySmall?.copyWith(color: scheme.inverseSurface),
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
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.titleMedium,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: scheme.primary),
          textStyle: textTheme.titleMedium,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
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
        labelStyle: textTheme.bodyMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStatePropertyAll(textTheme.bodySmall),
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
  static final ThemeData themeData = _buildCommon(const Color(0xFFFE724C));

  /// ثيم تطبيق العميل (فاتح/داكن)
  static final ThemeData clientTheme = _buildCommon(const Color(0xFFFE724C));
  static final ThemeData clientDarkTheme = _buildCommon(const Color(0xFFFE724C), dark: true);

  /// ثيم تطبيق المندوب (فاتح/داكن)
  static final ThemeData courierTheme = _buildCommon(const Color(0xFF2BA84A));
  static final ThemeData courierDarkTheme = _buildCommon(const Color(0xFF2BA84A), dark: true);

  /// ثيم تطبيق المتجر (فاتح/داكن)
  static final ThemeData storeTheme = _buildCommon(const Color(0xFFFF9800));
  static final ThemeData storeDarkTheme = _buildCommon(const Color(0xFFFF9800), dark: true);
}
