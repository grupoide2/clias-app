//view/screens/dashboard.dart
import 'package:chatbot/model/storage/storage.dart';
import 'package:chatbot/utils/connectivity_listener.dart';
import 'package:chatbot/view/screens/chat.dart';
import 'package:chatbot/view/screens/form_chat.dart';
import 'package:chatbot/view/screens/notifications.dart';
import 'package:chatbot/view/screens/maps_selector_screen.dart';
import 'package:chatbot/view/screens/resources.dart';
import 'package:chatbot/view/screens/scanner.dart';
import 'package:chatbot/view/widgets/custom_app_bar.dart';
import 'package:chatbot/view/widgets/custom_drawer.dart';
import 'package:chatbot/view/widgets/utils.dart';
import 'package:chatbot/view/widgets/custom_button.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:chatbot/model/requests/user.dart';
import 'package:chatbot/service/notification_service.dart';
import 'package:chatbot/service/paciente_service.dart';
import 'package:chatbot/service/recurso_service.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:chatbot/service/notification_state.dart';

final _log = Logger();

class Dashboard extends StatefulWidget {
  Dashboard({super.key, this.hasInternet = true});
  final bool hasInternet;
  static final GlobalKey<AutoSamplingPageState> globalKey =
      GlobalKey<AutoSamplingPageState>();

  @override
  State<Dashboard> createState() => AutoSamplingPageState();
}

class AutoSamplingPageState extends State<Dashboard> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  int _currentIndex = 0;
  bool deviceRegistered = false;
  bool videoComplete = false;
  bool hasUnreadNotifications = false;

  // Estado del automuestreo (bloquea el botón "Iniciar proceso" cuando el
  // dispositivo actualmente registrado ya tiene un examen).
  bool _automuestreoCompletado = false;
  String? _codigoAutomuestreo;
  String? _userDevice;

  // El tiempo de uso de la app se mide globalmente en AppUsageTracker (main.dart).

  @override
  void initState() {
    _log.i("[🔄] Inicializando Dashboard  -✅");
    _initializePlayer();
    _cargarEstadoAutomuestreo();
    super.initState();
  }

  Future<void> _cargarEstadoAutomuestreo() async {
    final userId = await secureStorage.read(key: "user_id");
    final device = await secureStorage.read(key: "user_device");
    if (userId == null) return;
    final estado = await PacienteService.getEstadoAutomuestreo(userId);
    if (!mounted) return;
    setState(() {
      _userDevice = device;
      _codigoAutomuestreo = estado.codigoDispositivo;
      _automuestreoCompletado = estado.completado &&
          estado.codigoDispositivo != null &&
          estado.codigoDispositivo == device;
    });
  }

  void actualizarNotificacionesDelDashboard() {
    if (mounted) {
      setState(() {
        _log.i(
            "⚠️ Actualizando notificaciones desde el exterior en el Dashboard");
        hasUnreadNotifications = true;
      });
    }
  }

  void irAPestanaRecursos() {
    setState(() {
      _currentIndex = 1; // El índice que corresponde a la pestaña de Recursos
    });
  }

  void irAPestanaPrincipal() {
    setState(() {
      _currentIndex = 0;
    });
  }

  Future<void> _checkDeviceRegistration() async {
    final dispositivo = await secureStorage.read(key: "user_device");
    if (mounted) {
      setState(() {
        deviceRegistered = dispositivo != null;
        _userDevice = dispositivo;
      });
    }
    await _cargarEstadoAutomuestreo();
  }

  Future<void> actualizarNotificaciones() async {
    final unread = NotificationState().hayNoLeidas;
    if (mounted) {
      setState(() {
        hasUnreadNotifications = unread;
      });
    }
  }

  Future<void> _initializePlayer() async {
    String? dispositivo = await secureStorage.read(key: "user_device");
    String? autoPlay = await secureStorage.read(key: "auto_play");
    //Agrega el token del dispositivo del usuario
    final userId = await secureStorage.read(key: "user_id");
    if (userId != null) {
      try {
        await NotificationService.cargarYGuardarNotificaciones(userId!);
        await actualizarNotificaciones();
      } on SessionExpiredException {
        _log.w("[!] Sesión expirada, redirigiendo al login");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            User.clear();
            context.go('/presentation');
          }
        });
        return;
      } catch (e) {
        _log.w("[!] No se pudieron cargar notificaciones: $e");
      }
    } else {
      _log.w(
          "[!] User ID not found in secure storage. Cannot register FCM token.");
    }
    const asset = 'assets/videos/automuestreo.mp4';
    final videoUrl = await RecursoService.videoUsoAppUrl();
    (VideoPlayerController, ChewieController) res;
    try {
      res = videoUrl != null
          ? await initializeVideoPlayer(videoUrl, network: true)
          : await initializeVideoPlayer(asset);
    } catch (_) {
      res = await initializeVideoPlayer(asset);
    }
    final video = res.$1;
    final chewie = res.$2;
    // Listener para saber si terminó el video
    video.addListener(() {
      if (video.value.position >= video.value.duration && !videoComplete) {
        setState(() {
          videoComplete = true;
        });
      }
    });

    setState(() {
      if (dispositivo != null) {
        deviceRegistered = true;
      }
      if (autoPlay == "off") {
        videoComplete = true;
      }
      _videoController = video;
      _chewieController = chewie;
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(helpButton: true),
      endDrawer: widget.hasInternet ? const CustomDrawer() : null,
      body: Column(
        children: [
          _buildTopNavBar(),
          Expanded(
            child: <Widget>[
              _buildBody(),
              Resources(),
              const MapsSelectorScreen(),
              Notifications(onNotificacionesLeidas: actualizarNotificaciones),
            ][_currentIndex],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Automuestreo",
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AllowedColors.black),
          ),
          const SizedBox(height: 15),
          Expanded(
              child: SingleChildScrollView(
            child: Column(
              children: [
                buildVideoPlayer(_videoController, _chewieController),
                const SizedBox(height: 20),
                Builder(builder: (context) {
                  final bloqueado = _automuestreoCompletado;
                  final puedeIniciar = !bloqueado && deviceRegistered;
                  final codigo = _codigoAutomuestreo ?? _userDevice ?? '';
                  return CustomButton(
                      color: puedeIniciar
                          ? const Color(0xFF002856)
                          : AllowedColors.gray,
                      label: bloqueado
                          ? "Dispositivo Registrado - Código: $codigo"
                          : "Iniciar proceso de Automuestreo",
                      onPressed: puedeIniciar
                          ? () {
                              Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => FormChat()))
                                  .then((_) => _cargarEstadoAutomuestreo());
                            }
                          : null,
                      size: 340);
                }),
                const SizedBox(height: 20),
                Builder(builder: (context) {
                  final puedeRegistrar = _automuestreoCompletado ||
                      (videoComplete && !deviceRegistered);
                  return CustomButton(
                      color: puedeRegistrar
                          ? AllowedColors.blue
                          : AllowedColors.gray,
                      label: "Registrar dispositivo de Automuestreo",
                      onPressed: puedeRegistrar
                          ? () {
                              Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              Scanner(deviceRegister: true)))
                                  .then((_) => _checkDeviceRegistration());
                            }
                          : null,
                      size: 340);
                }),
                const SizedBox(height: 15),
                Text(
                    "Este video explica el proceso de automuestreo. Sigue los pasos descritos para completar el procedimiento correctamente.",
                    style: TextStyle(fontSize: 12, color: AllowedColors.gray)),
                const SizedBox(height: 16),
                _buildFuentesMedicas(),
                const SizedBox(height: 16),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildFuentesMedicas() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCCCCCC), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Fuentes médicas:",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AllowedColors.black,
            ),
          ),
          const SizedBox(height: 6),
          _fuenteItem(
            "Organización Mundial de la Salud (OMS). Guías para la detección del VPH (2024).",
          ),
          const SizedBox(height: 4),
          _fuenteItem(
            "Ministerio de Salud Pública del Ecuador. Protocolo de tamizaje de cáncer de cuello uterino (2024).",
          ),
        ],
      ),
    );
  }

  Widget _fuenteItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("- ", style: TextStyle(fontSize: 12, color: Colors.black87)),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildTopNavBar() {
    const navHeight = 58.0;
    const robotDiameter = 50.0;

    Widget navItem(IconData active, IconData inactive, int idx, {Widget? badge}) {
      final isActive = _currentIndex == idx;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _currentIndex = idx),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: navHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                badge ?? Icon(isActive ? active : inactive, color: Colors.white, size: 24),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  width: isActive ? 20 : 0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: AllowedColors.blue,
      height: navHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Íconos izquierda y derecha con hueco central
          Row(
            children: [
              navItem(Icons.home, Icons.home_outlined, 0),
              navItem(Icons.folder, Icons.folder_outlined, 1),
              const SizedBox(width: robotDiameter + 16),
              navItem(Icons.map, Icons.map_outlined, 2),
              navItem(
                Icons.notifications,
                Icons.notifications_outlined,
                3,
                badge: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      _currentIndex == 3
                          ? Icons.notifications
                          : Icons.notifications_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    if (hasUnreadNotifications)
                      const Positioned(
                        right: -1,
                        top: -1,
                        child: CircleAvatar(radius: 5, backgroundColor: Colors.red),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Robot centrado verticalmente en la barra
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ConnectivityListener(child: Chat()),
              ),
            ),
            child: Container(
              width: robotDiameter,
              height: robotDiameter,
              decoration: const BoxDecoration(
                color: AllowedColors.blue,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: SvgPicture.asset("assets/icons/chatbot.svg"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

