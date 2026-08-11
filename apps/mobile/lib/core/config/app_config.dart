import 'dart:io';

class AppConfig {
  static const String appVersion = '1.0.0';

  // Workstation Wi-Fi network IP for physical mobile device connections
  static String get baseApiUrl {
    return 'http://192.168.1.6:3000';
  }
}
