import 'dart:async';

import 'package:chatbot/model/requests/message_request.dart';
import 'package:chatbot/service/connectivity_service.dart';
import 'package:chatbot/service/sesion_chat_service.dart';
import 'package:chatbot/service/chat_service.dart';
import 'package:chatbot/view/widgets/pdf_viewer.dart';
import 'package:chatbot/view/widgets/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:chatbot/model/storage/storage.dart';
import 'package:logging/logging.dart';

Logger _log = Logger('Chat');

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

class Chat extends StatefulWidget {
  const Chat({super.key});

  @override
  State<Chat> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<Chat> {
  bool isChecking = true;
  bool isOnline = false;
  final focusNode = FocusNode();
  final ChatService chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final initTimestamp = DateTime.now();
  String? _chatSessionId;
  int _mensajesPaciente = 0;
  bool _sesionFinalizada = false;

  bool _isLoading = false;
  int _loadingIndex = 0;
  Timer? _loadingTimer;
  List<Map<String, dynamic>>? _quickReplies;

  @override
  void initState() {
    super.initState();
    _checkInternet();
    _registrarInicioChatbot();
    chatService.connect();
    chatService.socket.on('bot_uttered', (data) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingTimer?.cancel(); // Detener animación
          _messages.removeWhere((msg) => msg["loading"] == true);
          if (data.containsKey('text')) {
            _messages.add({"text": "${data['text']}", "isBot": true});
          }

          if (data['quick_replies'] != null) {
            _quickReplies = List<Map<String, dynamic>>.from(
                data['quick_replies'] as List<dynamic>);
          }
        });
      }
    });
  }

  Future<void> _registrarInicioChatbot() async {
    final publicId = await secureStorage.read(key: "user_id");
    if (publicId == null) return;
    _chatSessionId = await SesionChatService.iniciarSesionChatbot(
      publicId: publicId,
      inicio: initTimestamp,
    );
  }

  Future<void> _checkInternet() async {
    setState(() => isChecking = true);
    isOnline = await ConnectivityService.hasInternetConnection();
    setState(() => isChecking = false);
    if (mounted && !isOnline) {
      showSnackBar(context, "Sin conexión a internet");
    }
  }

  void _sendMessage() async {
    _quickReplies = null;
    String message = _messageController.value.text.trim();
    if (message.isNotEmpty) {
      _mensajesPaciente++;
      setState(() {
        _messages.add({"text": message, "isBot": false});
        _isLoading = true;
        _messages.add({"text": '', "loading": true, "isBot": true});
      });

      FocusScope.of(context).unfocus();

      _startLoadingAnimation();

      chatService.sendMessage(message, await getUserId());
      _messageController.clear();
    }
  }

  /// Cierra la sesión de chatbot una sola vez (por "¿Salir del chat?" o al destruirse la pantalla).
  Future<void> _finalizarSesion() async {
    if (_sesionFinalizada || _chatSessionId == null) return;
    _sesionFinalizada = true;
    await SesionChatService.finalizarSesionChatbot(
      sessionId: _chatSessionId!,
      fin: DateTime.now(),
      mensajesPaciente: _mensajesPaciente,
    );
  }

  void _startLoadingAnimation() {
    _loadingTimer?.cancel();
    _loadingIndex = 0;
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isLoading) {
        timer.cancel();
        return;
      }
      setState(() {
        _loadingIndex = (_loadingIndex + 1) % 4;
      });
    });
  }

  @override
  void dispose() {
    // Red de seguridad: si la pantalla se destruye sin pasar por "¿Salir del chat?".
    _finalizarSesion();
    chatService.disconnect();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_messages.isEmpty) {
      _messages.add({
        "text":
            '👋 ¡Hola! Soy tu asistente virtual de salud.\nEstoy aquí para responder tus preguntas sobre el **Automuestreo, Virus del Papiloma Humano (VPH), Cáncer de Cuello Uterino (CCU)** y temas relacionados con tu salud sexual y reproductiva.\nSi tienes alguna duda, puedes preguntarme. ¡Estoy para ayudarte! 😊',
        "loading": false,
        "isBot": true
      });
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }

        final bool shouldPop = await modalYesNoDialog(
              context: context,
              title: "¿Salir del chat?",
              message: "Se perderá todo el contenido del chat.",
              onYes: () async {
                await _finalizarSesion();
              },
            ) ??
            false;

        if (context.mounted && shouldPop) {
          Navigator.of(context).pop();
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
                itemCount: _messages.length + (_quickReplies != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_quickReplies != null) {
                    index = index - 1;
                  }

                  if (index < 0) {
                    return _replyButtons(_quickReplies!);
                  }

                  final message = _messages[_messages.length - 1 - index];
                  final messageRequest = MessageRequest(
                      text: message["text"],
                      sender: message["isBot"] ? Sender.bot : Sender.user,
                      loading: message["loading"] ?? false);

                  return _buildChatBubble(messageRequest);
                },
              )),
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
        centerTitle: false);
  }

  Widget _buildChatBubble(MessageRequest message) {
    if (message.loading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AllowedColors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '.' * _loadingIndex,
            style: const TextStyle(fontSize: 12, color: AllowedColors.black),
          ),
        ),
      );
    }

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
    return Wrap(
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
                    _mostrarDialogo(context, answer["payload"]);
                  } else if (answer["title"] == "Ver imagen") {
                    showPdfDialog(context, answer["payload"]);
                  }
                },
              ))
          .toList(),
    );
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

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: isChecking
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(width: 10),
                Text("Verificando conexión..."),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: isOnline,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje...",
                      hintStyle:
                          TextStyle(color: AllowedColors.gray, fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AllowedColors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor:
                      isOnline ? AllowedColors.blue : AllowedColors.gray,
                  radius: 25,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: AllowedColors.white),
                    onPressed: isOnline ? _sendMessage : null,
                  ),
                ),
              ],
            ),
    );
  }

  void showPdfDialog(BuildContext context, String nombreArchivo) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(child: PDFViewer(pdfName: nombreArchivo)),
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: Icon(Icons.close, color: AllowedColors.red, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
