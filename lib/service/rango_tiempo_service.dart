import 'dart:convert';
import 'package:chatbot/model/storage/storage.dart';
import 'package:chatbot/service/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('RangoTiempoService');

typedef RangoOpcion = ({String codigo, String etiqueta});

/// Catálogo de rangos de tiempo por pregunta de salud sexual
/// (`MENSTRUACION` | `PAPANICOLAOU` | `VPH`). Endpoint público
/// `GET /rango-tiempo-examen?pregunta=...&soloActivos=true`.
///
/// Cachea el último resultado bueno en `secureStorage` y cae al fallback
/// embebido si no hay red.
sealed class RangoTiempoService {
  static const Map<String, List<RangoOpcion>> _fallback = {
    'MENSTRUACION': [
      (codigo: 'MENST_3_A_6_MESES', etiqueta: 'Entre 3 y 6 meses'),
      (codigo: 'MENST_6_A_12_MESES', etiqueta: 'Entre 6 y 12 meses'),
      (codigo: 'MENST_MAS_12_MESES', etiqueta: 'Más de 12 meses'),
    ],
    'PAPANICOLAOU': [
      (codigo: 'PAP_MENOS_1_ANIO', etiqueta: 'Menos de 1 año'),
      (codigo: 'PAP_1_A_3_ANIOS', etiqueta: 'De 1 a 3 años'),
      (codigo: 'PAP_MAS_3_ANIOS', etiqueta: 'Más de 3 años'),
      (codigo: 'PAP_NUNCA', etiqueta: 'Nunca'),
    ],
    'VPH': [
      (codigo: 'VPH_MENOS_1_ANIO', etiqueta: 'Menos de 1 año'),
      (codigo: 'VPH_1_A_3_ANIOS', etiqueta: 'De 1 a 3 años'),
      (codigo: 'VPH_MAS_3_ANIOS', etiqueta: 'Más de 3 años'),
      (codigo: 'VPH_NUNCA', etiqueta: 'Nunca'),
    ],
  };

  static List<RangoOpcion> fallback(String pregunta) =>
      _fallback[pregunta] ?? const [];

  static Future<List<RangoOpcion>> getRangos(String pregunta) async {
    try {
      final response = await http.get(
        ApiClient.uriWithParams('/rango-tiempo-examen', {
          'pregunta': pregunta,
          'soloActivos': 'true',
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final opciones = data
            .map((e) => (
                  codigo: (e as Map<String, dynamic>)['codigo'] as String,
                  etiqueta: e['etiqueta'] as String,
                ))
            .toList();
        if (opciones.isNotEmpty) {
          await secureStorage.write(
            key: 'cat_rango_$pregunta',
            value: jsonEncode(
                opciones.map((o) => {'c': o.codigo, 'e': o.etiqueta}).toList()),
          );
          return opciones;
        }
      }
      _log.warning('getRangos($pregunta): ${response.statusCode}');
    } catch (e) {
      _log.warning('getRangos($pregunta) falló: $e');
    }

    final cached = await secureStorage.read(key: 'cat_rango_$pregunta');
    if (cached != null) {
      try {
        return (jsonDecode(cached) as List<dynamic>)
            .map((e) => (
                  codigo: (e as Map<String, dynamic>)['c'] as String,
                  etiqueta: e['e'] as String,
                ))
            .toList();
      } catch (_) {}
    }
    return fallback(pregunta);
  }
}
