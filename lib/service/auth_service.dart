// ignore_for_file: use_build_context_synchronously
// showSnackBar guards calls on context with [mounted]

import 'dart:convert';
import 'package:chatbot/model/requests/user.dart';
import 'package:chatbot/model/requests/user_request.dart';
import 'package:chatbot/model/responses/user_response.dart';
import 'package:chatbot/service/api_client.dart';
import 'package:chatbot/service/notification_service.dart';
import 'package:chatbot/view/widgets/utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:chatbot/model/storage/storage.dart';
import 'package:chatbot/config/env.dart';

final _log = Logger('AuthService');

sealed class AuthService {
  static Future<UserResponse?> login(BuildContext context, User user) async {
    _log.info('POST /usuarios/autenticar');
    try {
      final response = await http.post(
        ApiClient.uri('/usuarios/autenticar'),
        headers: ApiClient.publicHeaders,
        body: jsonEncode({
          'nombreUsuario': user.nombreUsuario,
          'contrasena': user.contrasena,
          'appVersion': AppConfig.appVersion,
        }),
      );

      if (response.statusCode == 200) {
        final userResponse =
            UserResponse.fromJsonMap(jsonDecode(response.body));

        await secureStorage.write(key: 'user_id', value: userResponse.publicId);
        await secureStorage.write(key: 'user_token', value: userResponse.token);
        await secureStorage.write(
            key: 'user_device', value: userResponse.dispositivo);
        User.setCurrentUser(User(userResponse.nombre, userResponse.nombreUsuario,
            '*****', userResponse.dispositivo));

        final autoPlay = await secureStorage.read(key: 'auto_play');
        if (autoPlay == null) {
          await secureStorage.write(key: 'auto_play', value: 'on');
        }

        await NotificationService.registrarTokenFCM(userResponse.publicId);
        return userResponse;
      }

      final statusCode = response.statusCode;
      final mensaje = ApiClient.errorMessage(response.body);

      if (statusCode == 401) {
        showSnackBar(context,
            mensaje ?? 'Usuario o contraseña incorrectos',
            type: SnackBarType.error);
      } else if (statusCode == 400) {
        showSnackBar(context, mensaje ?? 'Solicitud inválida',
            type: SnackBarType.error);
      } else {
        showSnackBar(context, 'No se pudo conectar con el servidor',
            type: SnackBarType.error);
      }
    } catch (e) {
      _log.severe('Login failed: $e');
      showSnackBar(context, 'Inicio de sesión fallido',
          type: SnackBarType.error);
    }

    return null;
  }

  static Future<UserResponse?> signUp(
      BuildContext context, UserRequest user) async {
    _log.info('POST /usuarios/registro');
    try {
      final response = await http.post(
        ApiClient.uri('/usuarios/registro'),
        headers: ApiClient.publicHeaders,
        body: jsonEncode(user.toJson()),
      );

      if (response.statusCode == 200) {
        final userResponse =
            UserResponse.fromJsonMap(jsonDecode(response.body));

        await secureStorage.write(key: 'user_id', value: userResponse.publicId);
        await secureStorage.write(key: 'user_token', value: userResponse.token);
        await secureStorage.write(
            key: 'user_device', value: userResponse.dispositivo);
        await secureStorage.write(key: 'auto_play', value: 'on');

        await NotificationService.registrarTokenFCM(userResponse.publicId);
        await NotificationService.crearNotificacionBienvenida(
            userResponse.publicId);

        _log.info(
            'Guardado en storage: ID - ${userResponse.publicId} | Token - ${userResponse.token}');

        return userResponse;
      }

      final mensaje = ApiClient.errorMessage(response.body);
      showSnackBar(context, mensaje ?? 'No se pudo registrar el usuario',
          type: SnackBarType.error);
    } catch (e) {
      _log.severe('Signup failed: $e');
      showSnackBar(context, 'Registro de usuario fallido',
          type: SnackBarType.error);
    }
    return null;
  }

  static Future<String?> refreshToken(
      BuildContext context, String token) async {
    try {
      final response = await http.get(
        ApiClient.uri('/usuarios/validar'),
        headers: {'token': token, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        _log.fine('Token válido');
        return response.body.replaceAll('"', '');
      }
    } catch (e) {
      _log.severe('Validate token failed: $e');
      showSnackBar(context, 'Tu sesión ha caducado. Vuelve a iniciar sesión.',
          type: SnackBarType.warning);
    }
    return null;
  }

  static Future<bool> changePassword(
      BuildContext context, User user, String fecha) async {
    try {
      final response = await http.put(
        ApiClient.uri('/usuarios/cambiar-contrasena'),
        headers: ApiClient.publicHeaders,
        body: jsonEncode({
          'nombreUsuario': user.nombreUsuario,
          'contrasena': user.contrasena,
          'fechaNacimientoCambioPass': fecha,
        }),
      );

      if (response.statusCode == 200) {
        _log.fine('Password changed: User - ${user.nombreUsuario}');
        showSnackBar(context, 'Contraseña cambiada correctamente',
            type: SnackBarType.success);
        return true;
      }

      final mensaje = ApiClient.errorMessage(response.body);
      showSnackBar(context, mensaje ?? 'No se pudo cambiar la contraseña',
          type: SnackBarType.error);
    } catch (e) {
      _log.severe('Password change failed: $e');
      showSnackBar(context, 'Cambio de contraseña fallido',
          type: SnackBarType.error);
    }
    return false;
  }
}
