import 'dart:convert';
import 'package:chatbot/model/requests/encuesta_sus_request.dart';
import 'package:chatbot/service/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('EncuestaService');

class EncuestaService {
  static Future<bool> guardarEncuesta(EncuestaSusRequest request) async {
    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.post(
        ApiClient.uri('/api/encuesta_sus'),
        headers: headers,
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) return true;

      _log.warning('guardarEncuesta: ${response.statusCode}');
      return false;
    } catch (e, st) {
      _log.severe('guardarEncuesta failed: $e', e, st);
      return false;
    }
  }

  static Future<bool> verificarEncuestaCompletada(
      String cuentaUsuarioId) async {
    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.get(
        ApiClient.uri('/api/encuesta_sus/completada/$cuentaUsuarioId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) == true;
      }

      _log.warning('verificarEncuestaCompletada: ${response.statusCode}');
      return false;
    } catch (e, st) {
      _log.severe('verificarEncuestaCompletada failed: $e', e, st);
      return false;
    }
  }
}
