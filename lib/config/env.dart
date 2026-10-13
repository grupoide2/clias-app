import 'package:package_info_plus/package_info_plus.dart';

class AppConfig {
  static const bool isDevelopment = false; // ⚠️ CAMBIA A FALSE si es producción
  static const bool usingEmulator = false; // ⚠️ CAMBIA A FALSE si usas dispositivo real

  static String get baseUrl {
    if (isDevelopment) {
      return usingEmulator
          ? "http://10.0.2.2:9001" // Emulador
          : "http://192.168.18.5:9001"; // Dispositivo real (reemplaza con tu IP local)
    } else {
      return "https://clias.ucuenca.edu.ec"; // Producción
    }
  }

  static String _appVersion = "desconocida";

  // Tomado de `version:` en pubspec.yaml (sin build number)
  static String get appVersion => _appVersion;

  static Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    _appVersion = info.version;
  }
}
