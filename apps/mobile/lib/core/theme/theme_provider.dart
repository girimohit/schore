import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/bootstrap/bootstrap_notifier.dart';
import 'color_scheme.dart';
import 'theme_builder.dart';

import 'package:shared_preferences/shared_preferences.dart';

// Provider to manage app-wide ThemeMode
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _themeKey = 'user_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = prefs.getString(_themeKey);
      if (modeString != null) {
        state = ThemeMode.values.firstWhere(
          (e) => e.toString() == modeString,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (_) {}
  }

  Future<void> toggleTheme(bool isDark) async {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.toString());
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.toString());
    } catch (_) {}
  }
}

// Provider that dynamically resolves school branding and builds active ThemeData
final appThemeProvider = Provider.family<ThemeData, bool>((ref, isDark) {
  final bootstrapState = ref.watch(bootstrapProvider);
  final branding = bootstrapState.config?.branding;

  if (branding == null) {
    // Fallback to default styling tokens
    return ThemeBuilder.build(
      isDark ? AppColorScheme.defaultDark : AppColorScheme.defaultLight,
      isDark,
    );
  }

  final scheme = AppColorScheme.fromBranding(
    primaryHex: branding.primaryColor,
    secondaryHex: branding.secondaryColor,
    accentHex: branding.accentColor,
    isDark: isDark,
  );

  return ThemeBuilder.build(scheme, isDark);
});
