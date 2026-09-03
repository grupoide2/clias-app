// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:chatbot/model/requests/sesion_chat_request.dart';
import 'package:chatbot/model/storage/storage.dart';
import 'package:chatbot/service/api_client.dart';
import 'package:chatbot/service/connectivity_service.dart';
import 'package:chatbot/view/widgets/utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('SesionChatService');

sealed class SesionChatService {
  static Future<bool?> registrarInfoExamen(
      BuildContext context, SesionChatRequest sesion) async {
    final hasInternet = await ConnectivityService.hasInternetConnection();

    if (!hasInternet) {
      _log.warning('Sin internet — guardando formulario pendiente');
      await secureStorage.write(key: 'form_request', value: jsonEncode(sesion));
      if (context.mounted) {
        showSnackBar(context, 'Proceso de Automuestreo terminado correctamente!.',
            type: SnackBarType.success);
      }
      return true;
    }

    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.post(
        ApiClient.uri('/sesion-chat/usuario'),
        headers: headers,
        body: jsonEncode(sesion.toJson()),
      );

      if (response.statusCode == 200 && context.mounted) {
        showSnackBar(context, 'Proceso de Automuestreo terminado correctamente!.',
            type: SnackBarType.success);
        await secureStorage.delete(key: 'form_request');
        return true;
      }

      final mensaje = ApiClient.errorMessage(response.body);
      if (context.mounted) {
        showSnackBar(context,
            mensaje ?? 'No se pudo registrar la información del Automuestreo VPH',
            type: SnackBarType.error);
      }
    } catch (e) {
      _log.severe('registrarInfoExamen failed: $e');
      if (context.mounted) {
        showSnackBar(context, 'Registro de examen VPH fallido',
            type: SnackBarType.error);
      }
    }

    return null;
  }

  static Future<bool?> saveChatTime({
    required double tiempo,
    required String publicId,
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.put(
        ApiClient.uri('/usuarios/chat-time/$publicId'),
        headers: headers,
        body: jsonEncode({'tiempo': tiempo}),
      );

      if (response.statusCode == 200) {
        _log.info('Chat time guardado');
        return true;
      }

      _log.warning('saveChatTime: ${response.statusCode}');
      return false;
    } catch (e) {
      _log.severe('saveChatTime failed: $e');
      return false;
    }
  }

  static Future<String?> iniciarSesionChatbot({
    required String publicId,
    required DateTime inicio,
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.post(
        ApiClient.uri('/sesion-chat/chatbot/inicio'),
        headers: headers,
        body: jsonEncode({
          'cuentaPublicId': publicId,
          'inicio': inicio.toIso8601String(),
        }),
      );
      if (response.statusCode == 200) {
        final sessionId = response.body.replaceAll('"', '');
        _log.info('Sesión chatbot iniciada: $sessionId');
        return sessionId;
      }
      _log.warning('iniciarSesionChatbot: ${response.statusCode}');
      return null;
    } catch (e) {
      _log.severe('iniciarSesionChatbot failed: $e');
      return null;
    }
  }

  static Future<void> finalizarSesionChatbot({
    required String sessionId,
    required DateTime fin,
    int mensajesPaciente = 0,
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.put(
        ApiClient.uri('/sesion-chat/chatbot/$sessionId/fin'),
        headers: headers,
        body: jsonEncode({
          'fin': fin.toIso8601String(),
          'mensajesPaciente': mensajesPaciente,
        }),
      );
      if (response.statusCode == 200) {
        _log.info('Sesión chatbot finalizada (mensajes: $mensajesPaciente)');
      } else {
        _log.warning('finalizarSesionChatbot: ${response.statusCode}');
      }
    } catch (e) {
      _log.severe('finalizarSesionChatbot failed: $e');
    }
  }

  /// Registra que la paciente completó el formulario de automuestreo.
  /// Cuenta como sesión de chatbot exitosa (contador combinado en el backend).
  static Future<void> registrarAutomuestreoCompletado({
    required String publicId,
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.post(
        ApiClient.uri('/metricas/automuestreo/completado'),
        headers: headers,
        body: jsonEncode({'cuentaPublicId': publicId}),
      );
      if (response.statusCode == 200) {
        _log.info('Automuestreo completado registrado en métricas');
      } else {
        _log.warning('registrarAutomuestreoCompletado: ${response.statusCode}');
      }
    } catch (e) {
      _log.severe('registrarAutomuestreoCompletado failed: $e');
    }
  }

  static Future<void> guardarTiempoApp({
    required String publicId,
    required DateTime inicio,
    required DateTime fin,
  }) async {
    final tiempo = fin.difference(inicio).inSeconds / 60.0;
    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.put(
        ApiClient.uri('/usuarios/app-time/$publicId'),
        headers: headers,
        body: jsonEncode({
          'inicio': inicio.toIso8601String(),
          'fin': fin.toIso8601String(),
          'tiempo': tiempo,
        }),
      );
      if (response.statusCode == 200) {
        _log.info('Tiempo app guardado: $tiempo min');
      } else {
        _log.warning('guardarTiempoApp: ${response.statusCode}');
      }
    } catch (e) {
      _log.severe('guardarTiempoApp failed: $e');
    }
  }
}
