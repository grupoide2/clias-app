class NotificacionResponse {
  final String publicId;
  final String tipoNotificacion;
  final String titulo;
  final String mensaje;
  final String? accion;
  final String? tipoAccion;
  final String fecha;
  bool leido;

  NotificacionResponse({
    required this.publicId,
    required this.tipoNotificacion,
    required this.titulo,
    required this.mensaje,
    this.accion,
    this.tipoAccion,
    required this.fecha,
    required this.leido,
  });

  factory NotificacionResponse.fromJson(Map<String, dynamic> json) {
    return NotificacionResponse(
      publicId: json['publicId'] ?? '',
      tipoNotificacion: json['tipoNotificacion'] ?? '',
      titulo: json['titulo'] ?? '',
      mensaje: json['mensaje'] ?? '',
      tipoAccion: json['tipoAccion'],
      accion: json['accion'],
      // El backend envía `fechaCreacion`; se aceptan alias por compatibilidad.
      fecha: (json['fechaCreacion'] ?? json['fechaEnvio'] ?? '').toString(),
      leido: json['leido'] ?? false,
    );
  }

  /// Fecha/hora de llegada en formato corto e inteligente:
  /// `Hoy 14:30` · `Ayer 09:05` · `02/09/2026 14:30`. Vacío si no se puede parsear.
  String get fechaFormateada {
    final DateTime dt;
    try {
      dt = DateTime.parse(fecha).toLocal();
    } catch (_) {
      return '';
    }
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final dia = DateTime(dt.year, dt.month, dt.day);
    final hora =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final difDias = hoy.difference(dia).inDays;
    if (difDias == 0) return 'Hoy $hora';
    if (difDias == 1) return 'Ayer $hora';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $hora';
  }
  NotificacionResponse copyWith({
    String? publicId,
    String? tipoNotificacion,
    String? titulo,
    String? mensaje,
    String? accion,
    String? tipoAccion,
    String? fecha,
    bool? leido,
  }) {
    return NotificacionResponse(
      publicId: publicId ?? this.publicId,
      tipoNotificacion: tipoNotificacion ?? this.tipoNotificacion,
      titulo: titulo ?? this.titulo,
      mensaje: mensaje ?? this.mensaje,
      accion: accion ?? this.accion,
      tipoAccion: tipoAccion ?? this.tipoAccion,
      fecha: fecha ?? this.fecha,
      leido: leido ?? this.leido,
    );
  }
}
  
