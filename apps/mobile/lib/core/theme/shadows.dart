import 'package:flutter/material.dart';

class AppShadows {
  static List<BoxShadow> low(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> medium(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> high(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.12),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];
}
