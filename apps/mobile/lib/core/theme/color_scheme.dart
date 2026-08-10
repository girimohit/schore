import 'package:flutter/material.dart';

class AppColorScheme {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color error;
  final Color success;
  final Color warning;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  const AppColorScheme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.error,
    required this.success,
    required this.warning,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });

  // Default theme tokens matching modern sleek dark mode
  static const AppColorScheme defaultDark = AppColorScheme(
    primary: Color(0xFF6200EE),
    secondary: Color(0xFF03DAC6),
    accent: Color(0xFFFF0266),
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    error: Color(0xFFCF6679),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFFC107),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF),
    border: Color(0xFF2C2C2C),
  );

  // Default theme tokens matching modern eye-pleasing light mode
  static const AppColorScheme defaultLight = AppColorScheme(
    primary: Color(0xFF6200EE),
    secondary: Color(0xFF03DAC6),
    accent: Color(0xFFFF0266),
    background: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    error: Color(0xFFB00020),
    success: Color(0xFF388E3C),
    warning: Color(0xFFFFA000),
    textPrimary: Color(0xFF1D1D1F),
    textSecondary: Color(0xFF86868B),
    border: Color(0xFFE5E5EA),
  );

  // Parse color schemes dynamically from School configurations
  factory AppColorScheme.fromBranding({
    required String primaryHex,
    required String secondaryHex,
    required String accentHex,
    required bool isDark,
  }) {
    Color parseHex(String hex, Color fallback) {
      try {
        final buffer = StringBuffer();
        if (hex.length == 6 || hex.length == 7) buffer.write('ff');
        buffer.write(hex.replaceFirst('#', ''));
        return Color(int.parse(buffer.toString(), radix: 16));
      } catch (_) {
        return fallback;
      }
    }

    final prim = parseHex(primaryHex, isDark ? defaultDark.primary : defaultLight.primary);
    final sec = parseHex(secondaryHex, isDark ? defaultDark.secondary : defaultLight.secondary);
    final acc = parseHex(accentHex, isDark ? defaultDark.accent : defaultLight.accent);

    return isDark
        ? AppColorScheme(
            primary: prim,
            secondary: sec,
            accent: acc,
            background: const Color(0xFF121212),
            surface: const Color(0xFF1E1E1E),
            error: const Color(0xFFCF6679),
            success: const Color(0xFF4CAF50),
            warning: const Color(0xFFFFC107),
            textPrimary: const Color(0xFFFFFFFF),
            textSecondary: const Color(0xB3FFFFFF),
            border: const Color(0xFF2C2C2C),
          )
        : AppColorScheme(
            primary: prim,
            secondary: sec,
            accent: acc,
            background: const Color(0xFFF5F5F7),
            surface: const Color(0xFFFFFFFF),
            error: const Color(0xFFB00020),
            success: const Color(0xFF388E3C),
            warning: const Color(0xFFFFA000),
            textPrimary: const Color(0xFF1D1D1F),
            textSecondary: const Color(0xFF86868B),
            border: const Color(0xFFE5E5EA),
          );
  }
}
