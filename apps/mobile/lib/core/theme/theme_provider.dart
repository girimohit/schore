import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/bootstrap/bootstrap_notifier.dart';
import 'color_scheme.dart';
import 'theme_builder.dart';

// Provider to manage app-wide ThemeMode
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  void toggleTheme(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
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
