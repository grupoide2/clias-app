import 'package:chatbot/model/storage/storage.dart';
import 'package:chatbot/service/sesion_chat_service.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final _log = Logger('AppUsageTracker');

/// Observa el ciclo de vida de la app (arriba del Navigator) y acumula el
/// tiempo de uso desde el primer ingreso de la paciente, en cualquier pantalla.
/// Cada vez que la app pasa a segundo plano o se cierra, envía el tramo al backend.
class AppUsageTracker extends StatefulWidget {
  const AppUsageTracker({super.key, required this.child});

  final Widget child;

  @override
  State<AppUsageTracker> createState() => _AppUsageTrackerState();
}

class _AppUsageTrackerState extends State<AppUsageTracker>
    with WidgetsBindingObserver {
  DateTime _segmentStart = DateTime.now();
  bool _flushing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _flush();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _segmentStart = DateTime.now();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _flush();
        break;
      default:
        break;
    }
  }

  Future<void> _flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final inicio = _segmentStart;
      final fin = DateTime.now();
      _segmentStart = fin; // evita doble conteo del mismo tramo
      if (fin.difference(inicio).inSeconds < 1) return;

      final publicId = await secureStorage.read(key: 'user_id');
      if (publicId == null) return; // solo cuenta con usuario (post inicio de sesión)

      await SesionChatService.guardarTiempoApp(
        publicId: publicId,
        inicio: inicio,
        fin: fin,
      );
      _log.fine('Tramo de uso enviado: ${fin.difference(inicio).inSeconds}s');
    } catch (e) {
      _log.warning('AppUsageTracker flush falló: $e');
    } finally {
      _flushing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
