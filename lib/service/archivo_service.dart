import 'dart:convert';
import 'package:chatbot/model/responses/archivo_response.dart';
import 'package:chatbot/service/api_client.dart';
import 'package:chatbot/view/widgets/utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('ArchivoService');

sealed class ArchivoService {
  static Future<String?> getArchivo(BuildContext context, String nombre) async {
    try {
      final response = await http.get(
        ApiClient.uri('/archivo/nombre/$nombre'),
        headers: ApiClient.publicHeaders,
      );

      if (response.statusCode == 200) {
        final contenido =
            ArchivoResponse.fromJsonMap(jsonDecode(response.body)).contenido;
        _log.fine('Get file success: Name - $nombre');
        return contenido;
      }

      final mensaje = ApiClient.errorMessage(response.body);
      if (context.mounted) {
        showSnackBar(
            context, mensaje ?? 'No se pudo obtener el archivo solicitado.');
      }
    } catch (e) {
      _log.severe('getArchivo failed: $e');
      if (context.mounted) {
        showSnackBar(context, 'Consulta de archivo fallido.');
      }
    }

    return null;
  }
}
