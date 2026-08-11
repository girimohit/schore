import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class AppConfig {
  static const String appVersion = '1.0.0';

  static String get baseApiUrl {
    // 1. Web browser environment
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    // 2. Desktop environments
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return 'http://localhost:3000';
    }
    // 3. Mobile devices & Emulators (runs on the local Wi-Fi IP address)
    return 'http://192.168.1.6:3000';
  }
}
