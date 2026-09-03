import 'package:chatbot/config/form_fields_config.dart';
import 'package:chatbot/model/requests/inf_socioeconomica_request.dart';
import 'package:chatbot/model/requests/user_request.dart';
import 'package:chatbot/service/inf_socioeconomica_service.dart';
import 'package:chatbot/service/paciente_service.dart';
import 'package:chatbot/view/screens/terms_and_conditions.dart';
import 'package:chatbot/view/widgets/custom_button.dart';
import 'package:chatbot/view/widgets/utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SocioeconomicInformation extends StatefulWidget {
  const SocioeconomicInformation(
      {super.key, this.infoSocioeconomicaRequest, this.edit = false});

  final InfSocioeconomicaRequest? infoSocioeconomicaRequest;
  final bool edit;

  @override
  State<SocioeconomicInformation> createState() =>
      _SocioeconomicInfoFormState();
}

class _SocioeconomicInfoFormState extends State<SocioeconomicInformation>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();

  String? _selectedEducationLevel;
  String? _selectedIncome;
  String? _selectedWorkStatus;
  String? _selectedBonus;
  String? _selectedDependenciaUniversitaria = 'NO';
  String? _selectedOcupacionUniversitaria;
  final TextEditingController _occupationController = TextEditingController();

  // Se carga del catálogo (GET /ocupaciones?soloUniversidad=true); arranca con el fallback.
  List<String> _ocupacionesUni =
      List.of(InfSocioeconomicaService.ocupacionesUniFallback);

  final List<String> _educationLevels = [
    "NINGUNO",
    "PRIMARIA",
    "SECUNDARIA",
    "UNIVERSITARIA",
    "CENTRO DE ALBAFETIZACIÓN"
  ];

  final List<String> _incomeLevels = [
    "Menos de \$450",
    "\$450 - \$900",
    "\$901 - \$1350",
    "Más de \$1350"
  ];

  final List<String> _workStatusOptions = ["SI", "NO"];
  final List<String> _bonusOptions = ["SI", "NO"];
  final List<String> _dependenciaOptions = ["SI", "NO"];

  @override
  void initState() {
    super.initState();
    if (widget.infoSocioeconomicaRequest != null) {
      final info = widget.infoSocioeconomicaRequest!;
      _selectedEducationLevel = info.instruccion;
      _selectedIncome = info.ingresos;
      _selectedWorkStatus = info.trabajoRemunerado;
      _selectedBonus = info.recibeBono;

      final ocupacion = info.ocupacion ?? '';
      if (_ocupacionesUni.contains(ocupacion)) {
        _selectedDependenciaUniversitaria = 'SI';
        _selectedOcupacionUniversitaria = ocupacion;
      } else {
        _selectedDependenciaUniversitaria = 'NO';
        _occupationController.text = ocupacion;
      }
    }
    WidgetsBinding.instance.addObserver(this);
    _cargarOcupaciones();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a la app se recargan las ocupaciones por si el admin agregó una
    // mientras esta pantalla ya estaba abierta.
    if (state == AppLifecycleState.resumed) {
      _cargarOcupaciones();
    }
  }

  Future<void> _cargarOcupaciones() async {
    final lista = await InfSocioeconomicaService.getOcupacionesUniversidad();
    if (!mounted) return;
    setState(() {
      _ocupacionesUni = lista;
      final ocupacion = widget.infoSocioeconomicaRequest?.ocupacion ?? '';
      // Un valor guardado que ahora sí aparece en el catálogo pasa a "pertenece a la U".
      if (ocupacion.isNotEmpty &&
          _selectedDependenciaUniversitaria == 'NO' &&
          lista.contains(ocupacion)) {
        _selectedDependenciaUniversitaria = 'SI';
        _selectedOcupacionUniversitaria = ocupacion;
        _occupationController.clear();
      }
      // Si la selección actual ya no está en la lista, se limpia.
      if (_selectedOcupacionUniversitaria != null &&
          !lista.contains(_selectedOcupacionUniversitaria)) {
        _selectedOcupacionUniversitaria = null;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _occupationController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    if (_selectedIncome == null) return false;
    if (_selectedDependenciaUniversitaria == null) return false;
    if (_selectedDependenciaUniversitaria == 'SI' &&
        _selectedOcupacionUniversitaria == null) return false;
    return true;
  }

  String? get _ocupacionFinal {
    if (_selectedDependenciaUniversitaria == 'SI') {
      return _selectedOcupacionUniversitaria;
    }
    final texto = _occupationController.text.trim();
    return texto.isEmpty ? null : texto;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/images/logo_ucuenca_top.png',
          height: 50,
        ),
        actions: [
          TextButton(
              onPressed: () {
                modalYesNoDialog(
                  context: context,
                  title: "¿Cancelar?",
                  message: widget.edit
                      ? "¿Desea cancelar la edición de su cuenta? Se perderán todos los datos ingresados."
                      : "¿Desea cancelar la creación de su cuenta? Se perderán todos los datos ingresados.",
                  onYes: () {
                  if (widget.edit) {
                    Navigator.of(context)
                      ..pop()   // SocioeconomicInformation
                      ..pop();  // /personal-data
                  } else {
                    Navigator.of(context)
                      ..pop()
                      ..pop()
                      ..pop();
                  }
                },
                );
              },
              child: Text("Cancelar",
                  style: TextStyle(color: AllowedColors.red, fontSize: 12))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                "Información Socioeconómica",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AllowedColors.black,
                ),
              ),
              const SizedBox(height: 20),

              // Nivel de instrucción (oculto según config)
              if (FormFieldsConfig.showNivelInstruccion) ...[
                buildLabel("Nivel de instrucción"),
                buildDropdown(_educationLevels, _selectedEducationLevel,
                    (newValue) {
                  setState(() => _selectedEducationLevel = newValue);
                }, 'Elija una opción'),
                const SizedBox(height: 20),
              ],

              // Ingresos mensuales
              buildLabel("Ingresos mensuales*"),
              buildDropdown(_incomeLevels, _selectedIncome, (newValue) {
                setState(() => _selectedIncome = newValue);
              }, 'Elija una opción', requiredInput: true),

              const SizedBox(height: 20),

              // Dependencia Universitaria
              buildLabel("¿Pertenece a la Universidad de Cuenca?*"),
              buildDropdown(_dependenciaOptions, _selectedDependenciaUniversitaria,
                  (newValue) {
                setState(() {
                  _selectedDependenciaUniversitaria = newValue;
                  _selectedOcupacionUniversitaria = null;
                  _occupationController.clear();
                });
              }, 'Elija una opción'),

              const SizedBox(height: 20),

              // Ocupación principal: texto libre (NO) o dropdown (SI)
              if (_selectedDependenciaUniversitaria != null) ...[
                buildLabel(_selectedDependenciaUniversitaria == 'SI'
                    ? "Ocupación principal*"
                    : "Ocupación principal"),
                if (_selectedDependenciaUniversitaria == 'SI')
                  buildDropdown(
                    _ocupacionesUni,
                    _selectedOcupacionUniversitaria,
                    (newValue) {
                      setState(() => _selectedOcupacionUniversitaria = newValue);
                    },
                    'Elija su cargo',
                  )
                else
                  TextFormField(
                    controller: _occupationController,
                    style: TextStyle(fontSize: 15, color: AllowedColors.black),
                    decoration:
                        inputDecoration("Ejemplo: Profesor, Comerciante"),
                  ),
                const SizedBox(height: 20),
              ],

              // Trabajo remunerado (oculto según config)
              if (FormFieldsConfig.showTrabajoRemunerado) ...[
                buildLabel("¿Tiene trabajo remunerado?"),
                buildDropdown(_workStatusOptions, _selectedWorkStatus,
                    (newValue) {
                  setState(() => _selectedWorkStatus = newValue);
                }, 'Elija una opción'),
                const SizedBox(height: 20),
              ],

              // Recibe bono (oculto según config)
              if (FormFieldsConfig.showRecibeBono) ...[
                buildLabel("¿Recibe bono?"),
                buildDropdown(_bonusOptions, _selectedBonus, (newValue) {
                  setState(() => _selectedBonus = newValue);
                }, 'Elija una opción'),
                const SizedBox(height: 20),
              ],

              const SizedBox(height: 10),
              Center(child: _buildButtons(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return CustomButton(
        color: _isFormValid ? AllowedColors.blue : AllowedColors.gray,
        onPressed: _isFormValid ? () {
          UserRequest? user = UserRequest.getUserRequest();
          if (user != null) {
            final socioeconomica = InfSocioeconomicaRequest(
              FormFieldsConfig.showNivelInstruccion
                  ? _selectedEducationLevel
                  : null,
              _selectedIncome,
              FormFieldsConfig.showTrabajoRemunerado
                  ? _selectedWorkStatus
                  : null,
              _ocupacionFinal,
              FormFieldsConfig.showRecibeBono ? _selectedBonus : null,
              dependenciaUniversitaria: _selectedDependenciaUniversitaria,
            );

            user.paciente.infoSocioeconomica = socioeconomica;

            if (widget.edit) {
              final doneLoading = modalLoadingDialog(context: context);
              PacienteService.update(context, user.paciente).then((value) {
                doneLoading();
                if (context.mounted && value) context.go('/dashboard');
              });
            } else {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TermsAndConditions()));
            }
          }
        } : null,
        label: widget.edit ? "Guardar" : "Continuar");
  }
}
