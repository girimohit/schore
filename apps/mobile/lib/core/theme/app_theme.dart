import 'package:flutter/material.dart';
import 'color_scheme.dart';
import 'theme_builder.dart';

class AppTheme {
  static ThemeData get light => ThemeBuilder.build(AppColorScheme.defaultLight, false);
  static ThemeData get dark => ThemeBuilder.build(AppColorScheme.defaultDark, true);
}
