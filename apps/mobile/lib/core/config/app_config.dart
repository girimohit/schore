import 'dart:io';

class AppConfig {
  static const String appVersion = '1.0.0';
  
  // Dynamic resolution for Android emulator localhost vs iOS/Web
  static String get baseApiUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }
}
