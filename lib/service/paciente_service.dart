// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:chatbot/model/requests/dispositivo_request.dart';
import 'package:chatbot/model/requests/paciente_request.dart';
import 'package:chatbot/model/storage/storage.dart';
import 'package:chatbot/service/api_client.dart';
import 'package:chatbot/service/connectivity_service.dart';
import 'package:chatbot/view/widgets/utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('PacienteService');

class CodigoQrValidacion {
  final bool valido;
  final String mensaje;
  const CodigoQrValidacion(this.valido, this.mensaje);
}

class EstadoAutomuestreo {
  final bool completado;
  final String? codigoDispositivo;
  const EstadoAutomuestreo(this.completado, this.codigoDispositivo);
}

sealed class PacienteService {
  /// Valida el código escaneado contra la tabla codigos_qr del backend.
  /// Sin conexión: no bloquea (devuelve válido).
  static Future<CodigoQrValidacion> validarCodigoQr(String codigo) async {
    try {
      final response = await http.get(
        ApiClient.uri('/api/codigosqr/validar/${Uri.encodeComponent(codigo.trim())}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return CodigoQrValidacion(
          data['valido'] == true,
          (data['mensaje'] as String?) ??
              'El código no corresponde a un dispositivo válido del sistema.',
        );
      }
      _log.warning('validarCodigoQr: ${response.statusCode}');
      return const CodigoQrValidacion(
          false, 'No se pudo validar el código del dispositivo.');
    } catch (e) {
      _log.warning('validarCodigoQr falló: $e');
      return const CodigoQrValidacion(true, ''); // sin red → no bloquear
    }
  }

  /// Estado del automuestreo: si está completado y con qué código de dispositivo.
  static Future<EstadoAutomuestreo> getEstadoAutomuestreo(String publicId) async {
    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.get(
        ApiClient.uri('/paciente/estado-automuestreo/$publicId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final d = jsonDecode(response.body) as Map<String, dynamic>;
        return EstadoAutomuestreo(
            d['completado'] == true, d['codigoDispositivo'] as String?);
      }
      _log.warning('getEstadoAutomuestreo: ${response.statusCode}');
    } catch (e) {
      _log.warning('getEstadoAutomuestreo falló: $e');
    }
    return const EstadoAutomuestreo(false, null);
  }

  static Future<bool?> registrarDispositivo(
      BuildContext context, DispositivoRequest dispositivo) async {
    final hasInternet = await ConnectivityService.hasInternetConnection();

    if (!hasInternet) {
      await secureStorage.write(key: 'pending_device', value: 'true');
      showSnackBar(context, 'Dispositivo registrado correctamente',
          type: SnackBarType.success);
      return true;
    }

    try {
      final publicId = await secureStorage.read(key: 'user_id');
      final headers = await ApiClient.authHeaders();
      final response = await http.put(
        ApiClient.uri('/paciente/registrar-dispositivo/$publicId'),
        headers: headers,
        body: jsonEncode(dispositivo.toJson()),
      );

      if (response.statusCode == 200) {
        showSnackBar(context, 'Dispositivo registrado correctamente',
          type: SnackBarType.success);
        await secureStorage.delete(key: 'pending_device');
        return true;
      }

      final mensaje = ApiClient.errorMessage(response.body);
      showSnackBar(context, mensaje ?? 'No se pudo registrar el dispositivo',
          type: SnackBarType.error);
    } catch (e) {
      _log.severe('registrarDispositivo failed: $e');
      showSnackBar(context, 'Registro de dispositivo fallido',
          type: SnackBarType.error);
    }

    return null;
  }

  static Future<bool> update(
      BuildContext context, PacienteRequest request) async {
    final id = await secureStorage.read(key: 'user_id');
    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.put(
        ApiClient.uri('/paciente/editar/$id'),
        headers: headers,
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        _log.fine('User data updated');
        showSnackBar(context, 'Datos actualizados correctamente',
            type: SnackBarType.success);
        return true;
      }

      final mensaje = ApiClient.errorMessage(response.body);
      showSnackBar(context, mensaje ?? 'Actualización fallida',
          type: SnackBarType.error);
    } catch (e) {
      _log.severe('update failed: $e');
      if (context.mounted)
        showSnackBar(context, 'Ocurrió un error inesperado.',
            type: SnackBarType.error);
    }
    return false;
  }

  static Future<PacienteRequest?> getPaciente(BuildContext context) async {
    final id = await secureStorage.read(key: 'user_id');
    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.get(
        ApiClient.uri('/paciente/usuario/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return PacienteRequest.fromJson(jsonDecode(response.body));
      }

      final mensaje = ApiClient.errorMessage(response.body);
      showSnackBar(context, mensaje ?? 'Error al obtener la información',
          type: SnackBarType.error);
    } catch (e) {
      _log.severe('getPaciente failed: $e');
      if (context.mounted)
        showSnackBar(context, 'Ocurrió un error inesperado.',
            type: SnackBarType.error);
    }
    return null;
  }

  static Future<bool> verificarFichaSocioeconomica(String userId) async {
    final response = await http.get(
      ApiClient.uri('/info-socioeconomica/ficha/existe/$userId'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['existeFicha'] == true;
    }
    throw Exception('Error al verificar ficha socioeconómica');
  }

  static Future<bool> desactivarRecordatorioEntrega(String userId) async {
    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.put(
        ApiClient.uri('/notificaciones/programada/desactivar-entrega/$userId'),
        headers: headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      _log.severe('desactivarRecordatorioEntrega failed: $e');
      return false;
    }
  }
}
