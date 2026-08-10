import 'package:flutter/material.dart';
import 'color_scheme.dart';
import 'typography.dart';
import 'radius.dart';

class ThemeBuilder {
  static ThemeData build(AppColorScheme scheme, bool isDark) {
    final textTheme = AppTypography.textTheme(scheme.textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: scheme.background,
      
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: scheme.primary,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: scheme.secondary,
        onSecondary: isDark ? Colors.black : Colors.white,
        error: scheme.error,
        onError: Colors.white,
        surface: scheme.surface,
        onSurface: scheme.textPrimary,
      ),

      textTheme: textTheme,

      cardTheme: CardTheme(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderM,
          side: BorderSide(color: scheme.border, width: 1),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        border: Border(
          bottom: BorderSide(color: scheme.border, width: 1),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF262626) : const Color(0xFFF2F2F7),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.textSecondary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderM,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderM,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderM,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderM,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),

      buttonTheme: const ButtonThemeData(
        textTheme: ButtonTextTheme.primary,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderM,
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.border,
        thickness: 1,
        space: 1,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.l),
            topRight: Radius.circular(AppRadius.l),
          ),
        ),
      ),
    );
  }
}
