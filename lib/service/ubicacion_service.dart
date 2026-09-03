import 'dart:convert';
import 'package:chatbot/model/responses/ubicacion_response.dart';
import 'package:chatbot/service/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('UbicacionService');

class UbicacionService {
  static Future<List<UbicacionResponse>> fetchUbicaciones(
      {String? establecimiento}) async {
    final uri = establecimiento != null
        ? ApiClient.uriWithParams(
            '/api/ubicaciones', {'establecimiento': establecimiento})
        : ApiClient.uri('/api/ubicaciones');

    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return body.map((json) => UbicacionResponse.fromJson(json)).toList();
      }

      _log.warning('fetchUbicaciones: ${response.statusCode}');
      throw Exception('Error al cargar ubicaciones');
    } catch (e, st) {
      _log.severe('fetchUbicaciones failed: $e', e, st);
      rethrow;
    }
  }
}
