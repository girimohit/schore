import 'package:flutter/material.dart';

class AppSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 16.0;
  static const double l = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Reusable padding layouts
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingS = EdgeInsets.all(s);
  static const EdgeInsets paddingM = EdgeInsets.all(m);
  static const EdgeInsets paddingL = EdgeInsets.all(l);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);

  // Horizontal spacings
  static const SizedBox widthXS = SizedBox(width: xs);
  static const SizedBox widthS = SizedBox(width: s);
  static const SizedBox widthM = SizedBox(width: m);
  static const SizedBox widthL = SizedBox(width: l);

  // Vertical spacings
  static const SizedBox heightXS = SizedBox(height: xs);
  static const SizedBox heightS = SizedBox(height: s);
  static const SizedBox heightM = SizedBox(height: m);
  static const SizedBox heightL = SizedBox(height: l);
  static const SizedBox heightXL = SizedBox(height: xl);
}
