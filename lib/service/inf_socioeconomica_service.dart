// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:chatbot/model/requests/inf_socioeconomica_request.dart';
import 'package:chatbot/model/responses/info_socioeconomica_response.dart';
import 'package:chatbot/model/storage/storage.dart';
import 'package:chatbot/service/api_client.dart';
import 'package:chatbot/view/widgets/utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('InfoSocioService');

sealed class InfSocioeconomicaService {
  /// Lista embebida por si el catálogo no está disponible (sin red / error).
  static const List<String> ocupacionesUniFallback = [
    'CONTRATO DE SERVICIO',
    'TRABAJADORA',
    'EMPLEADA',
    'SERVICIOS PROFESIONALES',
    'DOCENTE',
    'ADMINISTRATIVA',
  ];

  /// Ocupaciones para pacientes que pertenecen a la Universidad de Cuenca.
  /// Endpoint público. Cachea el último resultado bueno y cae al fallback embebido.
  static Future<List<String>> getOcupacionesUniversidad() async {
    try {
      final response = await http.get(
        ApiClient.uriWithParams('/ocupaciones', {'soloUniversidad': 'true'}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final nombres = data
            .map((e) => (e as Map<String, dynamic>)['nombre'] as String)
            .toList();
        if (nombres.isNotEmpty) {
          await secureStorage.write(
              key: 'cat_ocupaciones_uni', value: jsonEncode(nombres));
          return nombres;
        }
      }
      _log.warning('getOcupacionesUniversidad: ${response.statusCode}');
    } catch (e) {
      _log.warning('getOcupacionesUniversidad falló: $e');
    }

    final cached = await secureStorage.read(key: 'cat_ocupaciones_uni');
    if (cached != null) {
      try {
        return (jsonDecode(cached) as List<dynamic>).cast<String>();
      } catch (_) {}
    }
    return ocupacionesUniFallback;
  }

  static Future<InfoSocioeconomicaResponse?> getInformacion(
      BuildContext context, String publicId) async {
    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.get(
        ApiClient.uri('/info-socioeconomica/usuario/$publicId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return InfoSocioeconomicaResponse.fromJsonMap(jsonDecode(response.body));
      }

      final mensaje = ApiClient.errorMessage(response.body);
      if (context.mounted) {
        showSnackBar(
            context, mensaje ?? 'No se pudo obtener la información del usuario');
      }
    } catch (e) {
      _log.severe('getInformacion failed: $e');
      if (context.mounted) {
        showSnackBar(context, 'Solicitud de información fallida');
      }
    }
    return null;
  }

  static Future<bool?> editarInformacion(BuildContext context,
      InfSocioeconomicaRequest informacion, String publicId) async {
    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.put(
        ApiClient.uri('/info-socioeconomica/editar/$publicId'),
        headers: headers,
        body: jsonEncode(informacion.toJson()),
      );

      if (response.statusCode == 200) return true;

      final mensaje = ApiClient.errorMessage(response.body);
      if (context.mounted) {
        showSnackBar(
            context, mensaje ?? 'No se pudo editar la información del usuario');
      }
    } catch (e) {
      _log.severe('editarInformacion failed: $e');
      if (context.mounted) {
        showSnackBar(context, 'Edición de información fallido');
      }
    }
    return null;
  }
}
