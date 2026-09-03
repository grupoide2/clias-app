import 'dart:convert';
import 'package:chatbot/config/env.dart';
import 'package:chatbot/model/storage/storage.dart';

/// Centraliza la URL base y los headers comunes para todos los servicios.
class ApiClient {
  static String get baseUrl => AppConfig.baseUrl;

  static Uri uri(String path) => Uri.parse('$baseUrl$path');

  static Uri uriWithParams(String path, Map<String, String> params) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: params);

  /// Headers para endpoints que requieren JWT.
  static Future<Map<String, String>> authHeaders() async {
    final token = await secureStorage.read(key: 'user_token') ?? '';
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Headers para endpoints públicos (registro, login).
  static const Map<String, String> publicHeaders = {
    'Content-Type': 'application/json',
  };

  /// Extrae el campo "mensaje" del body JSON de una respuesta de error.
  static String? errorMessage(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      if (data is Map) return data['mensaje'] as String?;
    } catch (_) {}
    return null;
  }
}
