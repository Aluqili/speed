import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);
  final ValueNotifier<Color?> accentSeed = ValueNotifier<Color?>(null);

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
  }

  void setAccentSeed(Color? seed) {
    accentSeed.value = seed;
  }
}