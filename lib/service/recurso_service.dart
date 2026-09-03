import 'dart:convert';
import 'package:chatbot/service/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('RecursoService');

sealed class RecursoService {
  /// Devuelve la URL de red del video de uso de la app si el backend lo tiene
  /// publicado (slug `video_uso_app`); `null` si no existe o no hay conexión.
  /// El llamador debe caer al asset embebido cuando esto devuelve `null`.
  static Future<String?> videoUsoAppUrl() async {
    try {
      final response = await http.get(
        ApiClient.uri('/recursos?tipo=VIDEO&soloActivos=true'),
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        final existe = list.any((e) =>
            e is Map && e['slug'] == 'video_uso_app');
        if (existe) {
          return ApiClient.uri('/recursos/video_uso_app').toString();
        }
      } else {
        _log.warning('videoUsoAppUrl: ${response.statusCode}');
      }
    } catch (e) {
      _log.warning('videoUsoAppUrl falló: $e');
    }
    return null;
  }
}
