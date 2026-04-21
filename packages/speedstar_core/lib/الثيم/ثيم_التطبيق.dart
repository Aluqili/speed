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
  static const Color courierPrimary = Color(0xFF8B5E34);
  static const Color courierAccent = Color(0xFFE1A44A);
  static const Color courierBackground = Color(0xFFFBF7F1);
  static const Color courierSurface = Color(0xFFFFFFFF);
  static const Color courierTextPrimary = Color(0xFF342417);
  static const Color courierTextSecondary = Color(0xFF7A6857);
  static const Color storePrimary = Color(0xFF0F766E);
  static const Color storeAccent = Color(0xFFF59E0B);
  static const Color storeBackground = Color(0xFFF4FBF8);
  static const Color storeSurface = Color(0xFFFFFFFF);
  static const Color storeTextPrimary = Color(0xFF12312C);
  static const Color storeTextSecondary = Color(0xFF5F766F);

  /// إنشاء ثيم من لون أساسي (seed)
  static ThemeData fromSeed(Color seed, {bool dark = false}) =>
      _buildCommon(seed, dark: dark);

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
      scaffoldBackgroundColor:
          dark ? const Color(0xFF121212) : clientBackground,
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
        contentTextStyle: readableTextTheme.bodyMedium
            ?.copyWith(color: scheme.onInverseSurface),
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
        titleTextStyle:
            readableTextTheme.titleLarge?.copyWith(color: scheme.onSurface),
        contentTextStyle: readableTextTheme.bodyMedium
            ?.copyWith(color: scheme.onSurfaceVariant),
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
        textStyle:
            readableTextTheme.bodySmall?.copyWith(color: scheme.inverseSurface),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: readableTextTheme.titleMedium,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: readableTextTheme.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: scheme.primary),
          textStyle: readableTextTheme.titleMedium,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFDFC),
        labelStyle: TextStyle(
            color: dark ? const Color(0xFFD1D5DB) : clientTextSecondary),
        hintStyle: TextStyle(
            color: dark ? const Color(0xFF9CA3AF) : clientTextSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selectedColor: scheme.primaryContainer,
        labelStyle: readableTextTheme.bodyMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            dark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFCFA),
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
  static final ThemeData clientDarkTheme =
      _buildCommon(_clientSeed, dark: true);

  /// ثيم تطبيق المندوب (فاتح/داكن)
  static final ThemeData courierTheme = _buildCourierTheme();
  static final ThemeData courierDarkTheme = _buildCourierTheme(dark: true);

  static ThemeData courierFromSeed(Color seed, {bool dark = false}) =>
      _buildCourierTheme(seed: seed, dark: dark);

  /// ثيم تطبيق المتجر (فاتح/داكن)
  static final ThemeData storeTheme = _buildStoreTheme();
  static final ThemeData storeDarkTheme = _buildStoreTheme(dark: true);

  static ThemeData _buildStoreTheme({bool dark = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: storePrimary,
      secondary: storeAccent,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: dark ? Brightness.dark : Brightness.light,
      fontFamily: 'Cairo',
    );
    final textTheme = base.textTheme.apply(
      bodyColor: dark ? const Color(0xFFE7F4EF) : storeTextPrimary,
      displayColor: dark ? const Color(0xFFF4FFFB) : storeTextPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: dark ? const Color(0xFF071513) : storeBackground,
      primaryColor: storePrimary,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF0B1F1B) : storeSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: storePrimary),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: storePrimary,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF102623) : storeSurface,
        elevation: dark ? 0 : 6,
        shadowColor: storePrimary.withOpacity(dark ? 0 : 0.08),
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            dark ? const Color(0xFF11302B) : const Color(0xFF163C35),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF0F2622) : Colors.white,
        hintStyle: TextStyle(
            color: dark ? const Color(0xFF9BC2B8) : storeTextSecondary),
        labelStyle: TextStyle(
            color: dark ? const Color(0xFFBFE1D8) : storeTextSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: storePrimary.withOpacity(0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: storePrimary.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: storePrimary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: storePrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle:
              textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: storePrimary,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: storePrimary.withOpacity(0.3)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle:
              textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor:
            dark ? const Color(0xFF11302B) : const Color(0xFFE7F6F2),
        selectedColor: storePrimary.withOpacity(0.14),
        secondarySelectedColor: storeAccent.withOpacity(0.18),
        side: BorderSide.none,
        labelStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: DividerThemeData(
        color: dark ? const Color(0xFF20443D) : const Color(0xFFDCEDE7),
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: storePrimary,
        unselectedItemColor: storeTextSecondary,
        backgroundColor: dark ? const Color(0xFF0B1F1B) : Colors.white,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF0B1F1B) : Colors.white,
        indicatorColor: storePrimary.withOpacity(0.14),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  static ThemeData _buildCourierTheme({Color? seed, bool dark = false}) {
    final primary = seed ?? courierPrimary;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: courierAccent,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: dark ? Brightness.dark : Brightness.light,
      fontFamily: 'Cairo',
    );
    final textTheme = base.textTheme.apply(
      bodyColor: dark ? const Color(0xFFEAF2FF) : courierTextPrimary,
      displayColor: dark ? Colors.white : courierTextPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor:
          dark ? const Color(0xFF1B140E) : courierBackground,
      primaryColor: primary,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF241A12) : courierSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primary),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: primary,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF2A1E15) : courierSurface,
        elevation: dark ? 0 : 8,
        shadowColor: primary.withOpacity(dark ? 0 : 0.08),
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF342417) : courierTextPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF2A1E15) : Colors.white,
        hintStyle: TextStyle(
            color: dark ? const Color(0xFFAFC4E8) : courierTextSecondary),
        labelStyle: TextStyle(
            color: dark ? const Color(0xFFC7D8F5) : courierTextSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primary.withOpacity(0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primary.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle:
              textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: primary.withOpacity(0.28)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle:
              textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor:
            dark ? const Color(0xFF3A291B) : const Color(0xFFF6E6CF),
        selectedColor: primary.withOpacity(0.14),
        side: BorderSide.none,
        labelStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: DividerThemeData(
        color: dark ? const Color(0xFF4A3422) : const Color(0xFFEADBC9),
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: courierTextSecondary,
        backgroundColor: dark ? const Color(0xFF221810) : Colors.white,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF221810) : Colors.white,
        indicatorColor: primary.withOpacity(0.14),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
