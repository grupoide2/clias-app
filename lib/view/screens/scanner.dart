// DESACTIVADO: el scanner ya no arma el ExamenVph/SaludSexual (ver _procesarCodigo).
// import 'package:chatbot/model/requests/examen_vph_request.dart';
// import 'package:chatbot/model/requests/salud_sexual_request.dart';
import 'package:chatbot/model/requests/sesion_chat_request.dart';
import 'package:chatbot/view/screens/scanner_result.dart';
import 'package:chatbot/view/widgets/custom_app_bar.dart';
import 'package:chatbot/view/widgets/custom_button.dart';
import 'package:chatbot/view/widgets/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class Scanner extends StatefulWidget {
  const Scanner(
      {super.key, this.deviceRegister = false, this.sesion});

  final bool deviceRegister;
  final SesionChatRequest? sesion;
  // DESACTIVADO (flujo previo a Fase 4): el scanner ya no recibe la salud sexual.
  // final SaludSexualRequest? salud;

  @override
  State<Scanner> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<Scanner> {
  // DESACTIVADO: el scanner ya no arma el examen VPH.
  // ExamenVphRequest? examen;
  bool _modoManual = false;
  final _codigoCtrl = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    formats: [BarcodeFormat.qrCode]
  );

  void _onQRScanned(BarcodeCapture capture) {
    if (capture.barcodes.isNotEmpty) {
      _procesarCodigo(capture.barcodes.first.rawValue ?? "");
    }
  }

  /// Procesa un código venga de la cámara o del ingreso manual.
  void _procesarCodigo(String code) {
    final qrData = code.trim().isEmpty ? "Código QR no válido" : code.trim();
    _scannerController.stop();
    // DESACTIVADO (flujo previo a Fase 4): antes, con `deviceRegister == false`,
    // aquí se armaba el ExamenVph a partir de la salud sexual y se enviaba al
    // guardar en el scanner. Ahora el automuestreo se guarda SOLO desde
    // form_chat.dart al tocar "Automuestreo completado".
    // if (!widget.deviceRegister) {
    //   examen = ExamenVphRequest(qrData, widget.salud!,
    //       DateTime.now().toIso8601String().split('.').first);
    //   widget.sesion!.examenVph = examen;
    // }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ScannerResultPage(
                qrData: qrData,
                deviceRegister: widget.deviceRegister,
                restartScanner: () {
                  _scannerController.start();
                  if (mounted) setState(() => _modoManual = false);
                },
                sesion: widget.sesion)));
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(profileButton: false),
      body: _modoManual
          ? SingleChildScrollView(child: _buildManual())
          : Column(
              children: [
                _buildSubtitle(),
                Expanded(child: _buildQRScanner()),
                _buildLinkManual(),
              ],
            ),
    );
  }

  Widget _buildSubtitle() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        "Automuestreo\nColoca el código QR dentro del recuadro para escanearlo automáticamente.",
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AllowedColors.black),
      ),
    );
  }

  Widget _buildQRScanner() {
    return MobileScanner(
      controller: _scannerController,
      onDetect: _onQRScanned,
    );
  }

  Widget _buildLinkManual() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Column(
        children: [
          Text("¿No puedes escanear el código?",
              style: TextStyle(fontSize: 13, color: AllowedColors.gray)),
          TextButton(
            onPressed: () {
              _scannerController.stop();
              setState(() => _modoManual = true);
            },
            child: Text("Ingresar código manualmente",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AllowedColors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildManual() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Text(
            "Escribe el código que aparece en la etiqueta del dispositivo.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AllowedColors.black),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codigoCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.singleLineFormatter,
            ],
            decoration: InputDecoration(
              hintText: "Ej: ABC12345-6789",
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            color: AllowedColors.blue,
            label: "Registrar dispositivo",
            onPressed: () {
              final c = _codigoCtrl.text.trim();
              if (c.isNotEmpty) _procesarCodigo(c);
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() => _modoManual = false);
              _scannerController.start();
            },
            child: Text("← Volver a escanear QR",
                style: TextStyle(color: AllowedColors.red)),
          ),
        ],
      ),
    );
  }
}
