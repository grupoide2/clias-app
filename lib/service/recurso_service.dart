import 'dart:convert';
import 'package:chatbot/service/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('RecursoService');

sealed class RecursoService {
  /// Devuelve la URL de red del recurso [slug] si el backend lo tiene publicado
  /// (tipo VIDEO, activo); `null` si no existe o no hay conexión. El llamador
  /// debe caer al asset embebido cuando esto devuelve `null`.
  static Future<String?> _videoUrlSiExiste(String slug) async {
    try {
      final response = await http.get(
        ApiClient.uri('/recursos?tipo=VIDEO&soloActivos=true'),
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        final existe = list.any((e) => e is Map && e['slug'] == slug);
        if (existe) {
          return ApiClient.uri('/recursos/$slug').toString();
        }
      } else {
        _log.warning('_videoUrlSiExiste($slug): ${response.statusCode}');
      }
    } catch (e) {
      _log.warning('_videoUrlSiExiste($slug) falló: $e');
    }
    return null;
  }

  /// Video guía del automuestreo (se muestra en el chatbot y en el dashboard).
  /// Slug `video_uso_app`.
  static Future<String?> videoUsoAppUrl() => _videoUrlSiExiste('video_uso_app');

  /// Video tutorial general de uso de la app (botón de ayuda "?" de la barra
  /// superior). Slug `video_tutorial_app`.
  static Future<String?> videoTutorialAppUrl() =>
      _videoUrlSiExiste('video_tutorial_app');
}
