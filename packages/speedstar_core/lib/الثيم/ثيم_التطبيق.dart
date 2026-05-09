import 'package:flutter/material.dart';

/// ثيم التطبيق: ألوان وخطوط وإعدادات عامة.
class AppThemeArabic {
  // ─── ألوان تطبيق العميل ─────────────────────────────────────────────────
  static const Color clientPrimary       = Color(0xFFD92B1A); // أحمر جريء
  static const Color clientPrimaryLight  = Color(0xFFF04020); // أحمر فاتح
  static const Color clientAccent        = Color(0xFFF5A623); // عنبري ذهبي
  static const Color clientBackground    = Color(0xFFF8F4EE); // كريمي دافئ
  static const Color clientSurface       = Color(0xFFFFFFFF);
  static const Color clientTextPrimary   = Color(0xFF1C110A); // حبر دافئ
  static const Color clientTextSecondary = Color(0xFFA0907E); // رملي
  static const Color clientSuccess       = Color(0xFF1A9644); // أخضر
  static const Color clientError         = Color(0xFFEF4444);
  static const Color _clientSeed         = clientPrimary;

  // ─── ألوان تطبيق المندوب ────────────────────────────────────────────────
  static const Color courierPrimary       = Color(0xFF8B5E34);
  static const Color courierAccent        = Color(0xFFE1A44A);
  static const Color courierBackground    = Color(0xFFFBF7F1);
  static const Color courierSurface       = Color(0xFFFFFFFF);
  static const Color courierTextPrimary   = Color(0xFF342417);
  static const Color courierTextSecondary = Color(0xFF7A6857);

  // ─── ألوان تطبيق المتجر ─────────────────────────────────────────────────
  static const Color storePrimary       = Color(0xFF0F766E);
  static const Color storeAccent        = Color(0xFFF59E0B);
  static const Color storeBackground    = Color(0xFFF4FBF8);
  static const Color storeSurface       = Color(0xFFFFFFFF);
  static const Color storeTextPrimary   = Color(0xFF12312C);
  static const Color storeTextSecondary = Color(0xFF5F766F);

  // ─── ثيم العميل الرئيسي ─────────────────────────────────────────────────
  static ThemeData fromSeed(Color seed, {bool dark = false}) =>
      _buildClientTheme(seed: seed, dark: dark);

  static final ThemeData clientTheme     = _buildClientTheme();
  static final ThemeData clientDarkTheme = _buildClientTheme(dark: true);

  /// ثيم افتراضي (يُستخدم من كود قديم)
  static final ThemeData themeData = _buildClientTheme();

  // ─── بناء ثيم العميل ────────────────────────────────────────────────────
  static ThemeData _buildClientTheme({Color? seed, bool dark = false}) {
    final primary = seed ?? _clientSeed;

    final scheme = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary:              dark ? const Color(0xFFFF6B5E) : primary,
      onPrimary:            Colors.white,
      primaryContainer:     dark ? const Color(0xFF7A1000) : const Color(0xFFFFE0DC),
      onPrimaryContainer:   dark ? const Color(0xFFFFE0DC) : const Color(0xFF5A0A00),
      secondary:            dark ? const Color(0xFFFFCA7A) : clientAccent,
      onSecondary:          dark ? const Color(0xFF5A3000) : Colors.white,
      secondaryContainer:   dark ? const Color(0xFF5A3000) : const Color(0xFFFFF0D0),
      onSecondaryContainer: dark ? const Color(0xFFFFF0D0) : const Color(0xFF5A3000),
      tertiary:             dark ? const Color(0xFF80CBC4) : const Color(0xFF1A9644),
      onTertiary:           Colors.white,
      tertiaryContainer:    dark ? const Color(0xFF003D36) : const Color(0xFFD4F0DC),
      onTertiaryContainer:  dark ? const Color(0xFFB2DFDB) : const Color(0xFF0A4020),
      error:                dark ? const Color(0xFFFF6E6E) : clientError,
      onError:              Colors.white,
      errorContainer:       dark ? const Color(0xFF8B0000) : const Color(0xFFFFEBEB),
      onErrorContainer:     dark ? const Color(0xFFFFCDD2) : const Color(0xFF7F0000),
      surface:              dark ? const Color(0xFF1C1209) : clientSurface,
      onSurface:            dark ? const Color(0xFFF5EDE8) : clientTextPrimary,
      surfaceContainerHighest: dark ? const Color(0xFF2E1005) : const Color(0xFFF0EBE1),
      onSurfaceVariant:     dark ? const Color(0xFFBBA89E) : clientTextSecondary,
      outline:              dark ? const Color(0xFF5A2A1A) : const Color(0xFFE8E1D4),
      outlineVariant:       dark ? const Color(0xFF3D1500) : const Color(0xFFF0EBE1),
      shadow:               Colors.black,
      scrim:                Colors.black,
      inverseSurface:       dark ? const Color(0xFFF5EDE8) : const Color(0xFF1C110A),
      onInverseSurface:     dark ? const Color(0xFF1C110A) : const Color(0xFFF8F4EE),
      inversePrimary:       dark ? primary : const Color(0xFFFF6B5E),
    );

    const fontFamily = 'Cairo';

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: dark ? Brightness.dark : Brightness.light,
      fontFamily: fontFamily,
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge:  const TextStyle(fontWeight: FontWeight.w900, fontSize: 34, letterSpacing: -0.5),
      displayMedium: const TextStyle(fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.3),
      displaySmall:  const TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
      headlineLarge: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
      headlineMedium:const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      headlineSmall: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      titleLarge:    const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
      titleMedium:   const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      titleSmall:    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      bodyLarge:     const TextStyle(fontWeight: FontWeight.w400, fontSize: 16, height: 1.5),
      bodyMedium:    const TextStyle(fontWeight: FontWeight.w400, fontSize: 14, height: 1.5),
      bodySmall:     const TextStyle(fontWeight: FontWeight.w400, fontSize: 12, height: 1.4),
      labelLarge:    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.1),
      labelMedium:   const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      labelSmall:    const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, letterSpacing: 0.5),
    ).apply(
      bodyColor:    dark ? const Color(0xFFEAEAEB) : clientTextPrimary,
      displayColor: dark ? const Color(0xFFF2F2F7) : clientTextPrimary,
    );

    return base.copyWith(
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: dark ? const Color(0xFF000000) : clientBackground,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      hintColor: dark ? const Color(0xFF636366) : const Color(0xFFC7C7CC),
      disabledColor: dark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC),

      // ─── AppBar ─────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF1C1C1E) : clientSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        iconTheme: IconThemeData(color: scheme.primary),
        actionsIconTheme: IconThemeData(color: scheme.primary),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: dark ? const Color(0xFFEAEAEB) : clientTextPrimary,
          letterSpacing: 0,
        ),
        toolbarHeight: 56,
        shape: Border(
          bottom: BorderSide(
            color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),

      // ─── Cards ──────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF2C2C2E) : clientSurface,
        elevation: dark ? 0 : 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: dark ? const Color(0xFF3A3A3C) : const Color(0xFFE8E1D4),
            width: 1,
          ),
        ),
      ),

      // ─── Buttons ────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: dark
              ? const Color(0xFF3A3A3C)
              : const Color(0xFFE5E5EA),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: scheme.primary, width: 1.5),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // ─── FloatingActionButton ────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
        ),
      ),

      // ─── Input ──────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        hintStyle: TextStyle(
          color: dark ? const Color(0xFF636366) : const Color(0xFFC7C7CC),
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        labelStyle: TextStyle(
          color: dark ? const Color(0xFFAEAEB2) : clientTextSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: dark ? const Color(0xFF8E8E93) : clientTextSecondary,
        suffixIconColor: dark ? const Color(0xFF8E8E93) : clientTextSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),

      // ─── Chip ───────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: dark
            ? const Color(0xFF2E1005)
            : const Color(0xFFF0EBE1),
        selectedColor: dark
            ? scheme.primary.withValues(alpha: 0.3)
            : const Color(0xFFFFDDD9),
        secondarySelectedColor: scheme.primaryContainer,
        disabledColor: dark
            ? const Color(0xFF2E1005)
            : const Color(0xFFF8F4EE),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: dark ? const Color(0xFFEAEAEB) : clientTextPrimary,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: scheme.primary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: StadiumBorder(
          side: BorderSide(
            color: dark ? const Color(0xFF3A3A3C) : const Color(0xFFE8E1D4),
            width: 1,
          ),
        ),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),

      // ─── Divider ─────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
        thickness: 0.5,
        space: 0,
      ),

      // ─── ListTile ───────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        iconColor: scheme.primary,
        textColor: dark ? const Color(0xFFEAEAEB) : clientTextPrimary,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minVerticalPadding: 12,
      ),

      // ─── Dialog ──────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF2C2C2E) : clientSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: dark ? const Color(0xFFEAEAEB) : clientTextPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 14,
          height: 1.5,
          color: dark ? const Color(0xFFAEAEB2) : clientTextSecondary,
        ),
      ),

      // ─── BottomSheet ────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? const Color(0xFF1C1C1E) : clientSurface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: dark ? const Color(0xFF1C1C1E) : clientSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 0,
        modalElevation: 24,
        dragHandleColor: dark ? const Color(0xFF48484A) : const Color(0xFFD1D1D6),
        dragHandleSize: const Size(40, 4),
        showDragHandle: true,
      ),

      // ─── SnackBar ───────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF2C2C2E) : const Color(0xFF1C1C1E),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: dark ? const Color(0xFFEAEAEB) : Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        elevation: 8,
      ),

      // ─── BottomNavigationBar ───────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF1C1C1E) : clientSurface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: dark ? const Color(0xFF636366) : const Color(0xFF8E8E93),
        selectedLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 10,
        ),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ─── NavigationBar ─────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF1C1209) : clientSurface,
        indicatorColor: dark
            ? scheme.primary.withValues(alpha: 0.2)
            : const Color(0xFFFFDDD9),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.primary, size: 24);
          }
          return IconThemeData(
            color: dark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: scheme.primary,
            );
          }
          return const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w500,
            fontSize: 11,
            color: Color(0xFF8E8E93),
          );
        }),
        elevation: 0,
        height: 64,
      ),

      // ─── TabBar ────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor:
            dark ? const Color(0xFF8E8E93) : clientTextSecondary,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: dark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        overlayColor: WidgetStatePropertyAll(
          scheme.primary.withValues(alpha: 0.08),
        ),
      ),

      // ─── ProgressIndicator ──────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 3,
        borderRadius: BorderRadius.circular(99),
      ),

      // ─── Scrollbar ──────────────────────────────────────────────────────
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(99),
        thumbColor: WidgetStatePropertyAll(
          dark
              ? const Color(0xFF48484A)
              : const Color(0xFFD1D1D6),
        ),
        thickness: const WidgetStatePropertyAll(3),
        interactive: true,
      ),

      // ─── Switch ──────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return dark ? const Color(0xFF636366) : const Color(0xFFBDBDBD);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return dark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      // ─── Checkbox ────────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(
          color: dark ? const Color(0xFF636366) : const Color(0xFFD1D1D6),
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),

      // ─── Tooltip ─────────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF3A3A3C) : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        preferBelow: false,
        verticalOffset: 16,
      ),
    );
  }

  // ─── ثيم المندوب ──────────────────────────────────────────────────────────
  static final ThemeData courierTheme     = _buildCourierTheme();
  static final ThemeData courierDarkTheme = _buildCourierTheme(dark: true);

  static ThemeData courierFromSeed(Color seed, {bool dark = false}) =>
      _buildCourierTheme(seed: seed, dark: dark);

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
      scaffoldBackgroundColor: dark ? const Color(0xFF1B140E) : courierBackground,
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
        shadowColor: primary.withValues(alpha: dark ? 0 : 0.08),
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
        hintStyle: TextStyle(color: dark ? const Color(0xFFAFC4E8) : courierTextSecondary),
        labelStyle: TextStyle(color: dark ? const Color(0xFFC7D8F5) : courierTextSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.12)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: primary.withValues(alpha: 0.28)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: dark ? const Color(0xFF3A291B) : const Color(0xFFF6E6CF),
        selectedColor: primary.withValues(alpha: 0.14),
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
        indicatorColor: primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ─── ثيم المتجر ───────────────────────────────────────────────────────────
  static final ThemeData storeTheme     = _buildStoreTheme();
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
        shadowColor: storePrimary.withValues(alpha: dark ? 0 : 0.08),
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF11302B) : const Color(0xFF163C35),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF0F2622) : Colors.white,
        hintStyle: TextStyle(color: dark ? const Color(0xFF9BC2B8) : storeTextSecondary),
        labelStyle: TextStyle(color: dark ? const Color(0xFFBFE1D8) : storeTextSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: storePrimary.withValues(alpha: 0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: storePrimary.withValues(alpha: 0.12)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: storePrimary,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: storePrimary.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: dark ? const Color(0xFF11302B) : const Color(0xFFE7F6F2),
        selectedColor: storePrimary.withValues(alpha: 0.14),
        secondarySelectedColor: storeAccent.withValues(alpha: 0.18),
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
        indicatorColor: storePrimary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
