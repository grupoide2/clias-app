import 'dart:async';
import 'dart:convert';

import 'package:chatbot/model/requests/examen_vph_request.dart';
import 'package:chatbot/model/requests/message_request.dart';
import 'package:chatbot/model/requests/salud_sexual_request.dart';
import 'package:chatbot/model/requests/sesion_chat_request.dart';
import 'package:chatbot/service/rango_tiempo_service.dart';
import 'package:chatbot/service/recurso_service.dart';
import 'package:chatbot/service/sesion_chat_service.dart';
import 'package:chatbot/view/widgets/custom_button.dart';
import 'package:chatbot/view/widgets/utils.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:chatbot/model/storage/storage.dart';
import 'package:logging/logging.dart';
import 'package:video_player/video_player.dart';

Logger _log = Logger('FormChat');

String? userId;

Future<String> getUserId() async {
  userId = await secureStorage.read(key: "user_id");
  if (userId != null) {
    _log.fine("Clean user ID: $userId");
  } else {
    _log.severe("User ID not found in secure storage.");
  }

  return userId!;
}

class FormChat extends StatefulWidget {
  const FormChat({super.key});

  @override
  State<FormChat> createState() => _ChatbotPageState();
}

// Textos exactos de las preguntas de salud sexual en assets/offline_form.json.
const _qMenstruacionPrefijo =
    'Todo listo! Hemos determinado que **sí eres apta para realizarte el Automuestreo**.';
const _qPap = '¿Hace cuánto fué tu útltimo examen de Papanicolaou (Pap)?';
const _qVph = '¿Cuándo fué tu última prueba de Virus del Papiloma Humano (VPH)?';
const _qParejas =
    'Por favor, indica el número de parejas sexuales que has tenido. (Ejemplo: 2)';

class _ChatbotPageState extends State<FormChat> with WidgetsBindingObserver {
  SesionChatRequest? sesionChat;
  SaludSexualRequest saludSexual = SaludSexualRequest(false, null, null, null, null, null, null);
  bool completeForm = false;
  bool colectInformation = false;
  bool _saliendo = false;
  bool _enviandoExamen = false;
  final focusNode = FocusNode();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic> offlineMessages = {};
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  bool inputNumber = false;
  bool showInputText = false;
  bool showDatePickerSelector = false;
  List<Map<String, dynamic>>? _quickReplies;

  final DateTime now = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime firstAllowedDate =
        DateTime(now.year, now.month - 3, now.day);
    final DateTime lastAllowedDate = now.subtract(Duration(days: 1));
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: firstAllowedDate,
      lastDate: lastAllowedDate,
    );
    if (picked != null) {
      setState(() {
        _messageController.text = picked
            .toIso8601String()
            .split("T")[0]
            .split("-")
            .reversed
            .join("/");
        showDatePickerSelector = false;
        _sendMessage();
      });
    }
  }

  void initSesionChat() async {
    sesionChat = SesionChatRequest(await getUserId(), null, null, DateTime.now().toIso8601String().split('.').first, null);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadChatForm();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a la app se recargan los catálogos de rangos de tiempo por si el
    // admin cambió una opción mientras el formulario ya estaba abierto.
    if (state == AppLifecycleState.resumed && offlineMessages.isNotEmpty) {
      _aplicarCatalogosRango(refrescarChips: true);
    }
  }

  void loadChatForm() async {
    final jsonString = await rootBundle.loadString('assets/offline_form.json');
    final Map<String, dynamic> data = json.decode(jsonString);
    offlineMessages = Map<String, dynamic>.from(data);
    // Aplica el fallback embebido de una vez para no bloquear el primer mensaje…
    _reescribirRangos(
      RangoTiempoService.fallback('PAPANICOLAOU'),
      RangoTiempoService.fallback('VPH'),
      RangoTiempoService.fallback('MENSTRUACION'),
    );
    _sendMessage(offlineMessages["Iniciar proceso"]);
    // …y refresca desde el backend en segundo plano.
    _aplicarCatalogosRango(refrescarChips: true);
  }

  /// Trae los 3 catálogos de rango de tiempo (`MENSTRUACION`, `PAPANICOLAOU`,
  /// `VPH`) y reescribe las `quick_replies` de esas preguntas en [offlineMessages].
  Future<void> _aplicarCatalogosRango({bool refrescarChips = false}) async {
    final pap = await RangoTiempoService.getRangos('PAPANICOLAOU');
    final vph = await RangoTiempoService.getRangos('VPH');
    final menst = await RangoTiempoService.getRangos('MENSTRUACION');
    if (!mounted || offlineMessages.isEmpty) return;
    _reescribirRangos(pap, vph, menst);

    if (!refrescarChips) return;
    // Si el usuario está justo en una de esas preguntas, refresca los chips.
    if (_quickReplies == null || _messages.isEmpty) return;
    final ultima = (_messages.last['response'] ?? '').toString();
    List<Map<String, dynamic>>? nuevos;
    if (ultima == _qPap) {
      nuevos = _rangoQuickReplies(pap, _qVph, numerico: false);
    } else if (ultima == _qVph) {
      nuevos = _rangoQuickReplies(vph, _qParejas, numerico: true);
    } else if (ultima.startsWith(_qMenstruacionPrefijo)) {
      nuevos = _rangoQuickReplies(menst, _qPap,
          numerico: false, payloadEtiqueta: true);
    }
    if (nuevos != null) setState(() => _quickReplies = nuevos);
  }

  void _reescribirRangos(
    List<RangoOpcion> pap,
    List<RangoOpcion> vph,
    List<RangoOpcion> menst,
  ) {
    final nodoPap = offlineMessages['selecciono_fecha'];
    if (nodoPap is Map) {
      nodoPap['quick_replies'] = _rangoQuickReplies(pap, _qVph, numerico: false);
    }
    final nodoVph = offlineMessages['ultimo_pap'];
    if (nodoVph is Map) {
      nodoVph['quick_replies'] =
          _rangoQuickReplies(vph, _qParejas, numerico: true);
    }
    _reescribirMenstruacion(offlineMessages, menst);
  }

  List<Map<String, dynamic>> _rangoQuickReplies(
    List<RangoOpcion> catalogo,
    String siguiente, {
    required bool numerico,
    bool payloadEtiqueta = false,
  }) {
    return [
      for (final r in catalogo)
        {
          'title': r.etiqueta,
          'payload': payloadEtiqueta ? r.etiqueta : r.codigo,
          'response': siguiente,
          'isBot': true,
          if (numerico) 'teclado_numerico': true else 'quick_replies': <dynamic>[],
        }
    ];
  }

  void _reescribirMenstruacion(dynamic nodo, List<RangoOpcion> menst) {
    if (nodo is Map) {
      if (nodo['selector_fecha'] == true && nodo['quick_replies'] is List) {
        nodo['quick_replies'] =
            _rangoQuickReplies(menst, _qPap, numerico: false, payloadEtiqueta: true);
      }
      nodo.forEach((_, v) => _reescribirMenstruacion(v, menst));
    } else if (nodo is List) {
      for (final e in nodo) {
        _reescribirMenstruacion(e, menst);
      }
    }
  }

  void _initVideoPlayer() async {
    const asset = 'assets/videos/automuestreo.mp4';
    final url = await RecursoService.videoUsoAppUrl();
    (VideoPlayerController, ChewieController) res;
    try {
      res = url != null
          ? await initializeVideoPlayer(url, network: true, autoPlay: false)
          : await initializeVideoPlayer(asset, autoPlay: false);
    } catch (_) {
      res = await initializeVideoPlayer(asset, autoPlay: false);
    }
    _videoController = res.$1;
    _chewieController = res.$2;

    if (mounted) setState(() {});
  }

  void _sendMessage([Map<String, dynamic>? dataPayload]) async {
    showInputText = false;
    if (dataPayload != null && dataPayload.containsKey('selector_fecha')) {
      showDatePickerSelector = true;
    }
    if (dataPayload != null && dataPayload.containsKey('teclado_numerico')) {
      inputNumber = true;
    }
    _quickReplies = null;
    String message =
        dataPayload?['title'] ?? _messageController.value.text.trim();
    if (message.isNotEmpty) {
      if (_messages.isNotEmpty) {
        if (_messages.last["response"].toString().startsWith(
            "Todo listo! Hemos determinado que **sí eres apta para realizarte el Automuestreo**.")) {
          saludSexual.fechaUltimaMenstruacion =
              dataPayload?['payload'] ?? message;
          dataPayload = offlineMessages["selecciono_fecha"];
        } else if (_messages.last["response"] ==
            "¿Hace cuánto fué tu útltimo examen de Papanicolaou (Pap)?") {
          saludSexual.ultimoExamenPap = dataPayload?['payload'];
          dataPayload = offlineMessages["ultimo_pap"];
        } else if (_messages.last["response"] ==
            "¿Cuándo fué tu última prueba de Virus del Papiloma Humano (VPH)?") {
          saludSexual.tiempoPruebaVph = dataPayload?['payload'];
        } else if (_messages.last["response"].toString().startsWith(
            "Por favor, indica el número de parejas sexuales que has tenido")) {
          saludSexual.numParejasSexuales = int.parse(message);
          dataPayload = offlineMessages["teclado_numerico"];
        } else if (_messages.last["response"] ==
            "¿Estás con tu período menstrual en este momento?") {
          saludSexual.estaMenstruando = dataPayload?['payload'] as String?;
        } else if (_messages.last["response"].toString().startsWith(
            "¿Ha sido diagnosticado o sospecha de tener alguna Infección de Transmisión Sexual")) {
          saludSexual.tieneEts = message;
        } else if (_messages.last["response"].toString().startsWith(
            "Por favor, indica el nombre de la Infección de Transmisión Sexual (ITS) que tienes")) {
          saludSexual.nombreEts = message;
        }
      }
      setState(() {
        _messages.add({"response": message, "isBot": false});
      });

      FocusScope.of(context).unfocus();

      if (dataPayload?["response"] == "formulario_completo") {
        dataPayload = offlineMessages["formulario_completo"];
      }

      _messages.add({"response": dataPayload?['response'], "isBot": true});

      final qrRaw = dataPayload?['quick_replies'];
      if (qrRaw is List && qrRaw.isNotEmpty) {
        _quickReplies = List<Map<String, dynamic>>.from(qrRaw);

        bool processFinished = _quickReplies!
            .any((answer) => (answer["title"] == "Automuestreo completado"));

        if (processFinished) {
          _initVideoPlayer();
          completeForm = true;
          _log.fine(jsonEncode(saludSexual).toString());
        }
      }

      if (_messages.isNotEmpty &&
          !_messages.last["response"].toString().startsWith(
              "Por favor, indica el número de parejas sexuales que has tenido") &&
          inputNumber) {
        inputNumber = false;
        dataPayload = offlineMessages["teclado_numerico"];
      }
      if (_messages.isNotEmpty &&
          !_messages.last["response"].toString().startsWith(
              "Todo listo! Hemos determinado que **sí eres apta para realizarte el Automuestreo**.") &&
          showDatePickerSelector) {
        showDatePickerSelector = false;
      }
    }
    _messageController.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    focusNode.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  /// El formulario llegó a un punto sin continuación: el bot mostró un mensaje
  /// (normalmente de descalificación) y no ofrece respuestas ni pide datos.
  /// Se muestra el botón "Entiendo, salir". Estas respuestas NO se registran.
  bool get _formularioSinSalida {
    if (completeForm) return false;
    if (_quickReplies != null && _quickReplies!.isNotEmpty) return false;
    if (showInputText || inputNumber || showDatePickerSelector) return false;
    if (_messages.isEmpty || _messages.last["isBot"] != true) return false;
    // Debe existir al menos una respuesta de la paciente (no es el saludo inicial).
    return _messages.any((m) => m["isBot"] == false);
  }

  void _salirDelFormulario() {
    setState(() => _saliendo = true);
    Navigator.of(context).maybePop();
  }

  Widget _botonSalirEnLinea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: CustomButton(
          color: AllowedColors.red,
          label: "Entiendo, salir",
          onPressed: _salirDelFormulario,
        ),
      ),
    );
  }

  Future<void> _finalizarAutomuestreo() async {
    if (_enviandoExamen) return;
    final device = await secureStorage.read(key: "user_device");
    if (device == null || device.isEmpty) {
      if (mounted) {
        showSnackBar(context, "No hay un dispositivo de automuestreo registrado.",
            type: SnackBarType.error);
      }
      return;
    }
    setState(() => _enviandoExamen = true);
    final fecha = DateTime.now().toIso8601String().split('.').first;
    sesionChat!.fin = fecha;
    sesionChat!.contenido = jsonEncode(_messages);
    sesionChat!.examenVph = ExamenVphRequest(device, saludSexual, fecha);

    if (!mounted) return;
    final ok = await SesionChatService.registrarInfoExamen(context, sesionChat!);
    if (ok == true) {
      final uid = await secureStorage.read(key: "user_id");
      if (uid != null) {
        await SesionChatService.registrarAutomuestreoCompletado(publicId: uid);
      }
      if (mounted) {
        _saliendo = true;
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else if (mounted) {
      setState(() => _enviandoExamen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    initSesionChat();
    return PopScope(
      canPop: _saliendo || _formularioSinSalida,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }

        final bool shouldPop = await modalYesNoDialog(
              context: context,
              title: "¿Salir del chat?",
              message: "Se perderá todo el proceso de Automuestreo.",
              onYes: () {},
            ) ??
            false;

        if (context.mounted && shouldPop) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                  child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(10),
                itemCount: _messages.length +
                    ((_quickReplies != null || _formularioSinSalida) ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_quickReplies != null || _formularioSinSalida) {
                    index = index - 1;
                  }

                  if (index < 0) {
                    return _quickReplies != null
                        ? _replyButtons(_quickReplies!)
                        : _botonSalirEnLinea();
                  }

                  final message = _messages[_messages.length - 1 - index];
                  final messageRequest = MessageRequest(
                      text: message["response"],
                      sender: message["isBot"] ? Sender.bot : Sender.user,
                      loading: message["loading"] ?? false);

                  return _buildChatBubble(messageRequest);
                },
              )),
              if (!_formularioSinSalida &&
                  (_quickReplies == null || showInputText))
                _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      iconTheme: IconThemeData(color: AllowedColors.gray),
      elevation: 10,
      title: Row(
        children: [
          Image.asset('assets/images/chatbot.png',
              height: 30), // Ícono del chatbot
          const SizedBox(width: 10),
          Text(
            "SISA CHAT",
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AllowedColors.red),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        if (completeForm)
          IconButton(
            icon: Icon(Icons.check_circle_outline,
                size: 30, color: AllowedColors.blue),
            tooltip: "Automuestreo completado",
            onPressed: _enviandoExamen ? null : _finalizarAutomuestreo,
          ),
      ],
    );
  }

  Widget _buildChatBubble(MessageRequest message) {
    bool isBot = message.sender == Sender.bot;
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isBot ? AllowedColors.white : AllowedColors.blue,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft:
                isBot ? const Radius.circular(0) : const Radius.circular(12),
            bottomRight:
                isBot ? const Radius.circular(12) : const Radius.circular(0),
          ),
        ),
        child: MarkdownBody(
          data: message.text.replaceAll("\n", "  \n"),
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
                color: isBot ? AllowedColors.black : AllowedColors.white),
          ),
        ),
      ),
    );
  }

  Widget _replyButtons(List<Map<String, dynamic>> answers) {
    var buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: answers
          .map((answer) => ElevatedButton(
                child: Text(
                  answer["title"]!,
                  style: const TextStyle(fontSize: 15),
                ),
                onPressed: () {
                  if (answer["title"] == "Más información") {
                    _mostrarDialogo(context, answer["response"]);
                  } else if (answer["title"] == "Ver video") {
                    showVideoDialog(context);
                  } else if (answer["title"] == "Automuestreo completado") {
                    _finalizarAutomuestreo();
                  } else {
                    _sendMessage(answer);
                  }
                },
              ))
          .toList(),
    );

    if (showDatePickerSelector) {
      buttons.children.add(_dateSelector());
    }
    return buttons;
  }

  void _mostrarDialogo(BuildContext context, String text) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AllowedColors.white,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.9,
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Más información",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: MarkdownBody(
                      data: text.replaceAll("\n", "  \n"),
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(color: AllowedColors.black),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Cierra el diálogo
                    },
                    child: Text(
                      "Cerrar",
                      style: TextStyle(color: AllowedColors.blue),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dateSelector() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        backgroundColor: AllowedColors.white,
        elevation: 2,
      ),
      onPressed: () {
        _selectDate(context);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child:
                Icon(Icons.calendar_today, color: AllowedColors.gray, size: 20),
          ),
          Expanded(
            child: Text(
              "dd/MM/yyyy",
              style: TextStyle(fontSize: 16, color: AllowedColors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              keyboardType:
                  inputNumber ? TextInputType.number : TextInputType.text,
              inputFormatters: [
                inputNumber
                    ? FilteringTextInputFormatter.digitsOnly
                    : FilteringTextInputFormatter.singleLineFormatter
              ],
              decoration: InputDecoration(
                hintText: "Ingresa un número...",
                hintStyle: TextStyle(color: AllowedColors.gray, fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AllowedColors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: AllowedColors.blue,
            radius: 25,
            child: IconButton(
              icon: const Icon(Icons.send, color: AllowedColors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void showVideoDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true, // Permite que el diálogo ocupe más espacio
      backgroundColor: Colors.transparent, // Fondo transparente
      builder: (context) {
        return Container(
          width: double.infinity, // Ocupa todo el ancho disponible
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white, // Fondo del diálogo
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: Icon(Icons.close, color: AllowedColors.red, size: 24),
                  onPressed: () {
                    _videoController?.pause();
                    Navigator.pop(context);
                  },
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: buildVideoPlayer(_videoController, _chewieController),
                ),
              ),
              SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: CustomButton(
                  color: AllowedColors.red,
                  onPressed: () {
                    _videoController?.pause();
                    Navigator.pop(context);
                  },
                  label: "Entendido",
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
