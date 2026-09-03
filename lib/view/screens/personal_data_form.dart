import 'package:chatbot/model/requests/paciente_request.dart';
import 'package:chatbot/model/requests/user.dart';
import 'package:chatbot/model/requests/user_request.dart';
import 'package:chatbot/view/screens/socioeconomic_information.dart';
import 'package:chatbot/view/widgets/custom_button.dart';
import 'package:chatbot/view/widgets/utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PersonalDataForm extends StatefulWidget {
  const PersonalDataForm({super.key, this.pacienteRequest, this.edit = false});

  final PacienteRequest? pacienteRequest;
  final bool edit;

  @override
  State<PersonalDataForm> createState() => _PersonalDataFormState();
}

class _PersonalDataFormState extends State<PersonalDataForm> {
  final _formKey = GlobalKey<FormState>();

  final List<String> _countries = [
    "ECUADOR",
    "VENEZUELA",
    "COLOMBIA",
    "PERU",
    "CHILE",
    "ARGENTINA",
    "BOLIVIA",
    "URUGUAY",
    "BRAZIL"
  ];
  final List<String> _languages = ["ESPAÑOL", "INGLÉS", "OTRO"];
  final List<String> _maritalStatusOptions = [
    "SOLTERO/A",
    "CASADO/A",
    "DIVORCIADO/A",
    "VIUDO/A",
    "UNIÓN LIBRE"
  ];
  final List<String> _genders = ["MASCULINO", "FEMENINO", "OTRO"];

  final List<String> _residentialZones = [
    "RURAL",
    "URBANA"
  ];

  final TextEditingController dateController = TextEditingController();

  String? _selectedCountry;
  String? _selectedLanguage;
  String? _selectedMaritalStatus;
  String? _selectedGender;
  String? _selectedResidentialZone;

  @override
  void initState() {
    super.initState();

    if (widget.pacienteRequest != null) {
      setState(() {
        _selectedCountry = widget.pacienteRequest!.pais;
        _selectedLanguage = widget.pacienteRequest!.lenguaMaterna;
        _selectedMaritalStatus = widget.pacienteRequest!.estadoCivil;
        _selectedGender = widget.pacienteRequest!.sexo;
        _selectedResidentialZone = widget.pacienteRequest!.zonaResidencial.isEmpty
            ? null
            : widget.pacienteRequest!.zonaResidencial;
        dateController.text = widget.pacienteRequest!.fechaNacimiento;
      });
    } else {
      setState(() {
        _selectedCountry = _countries[0];
        _selectedLanguage = _languages[0];
        _selectedMaritalStatus = _maritalStatusOptions[0];
        _selectedGender = _genders[1];
        _selectedResidentialZone = _residentialZones[0];
      });
    }
  }

  bool get _isFormValid =>
      dateController.text.isNotEmpty &&
      _selectedCountry != null &&
      _selectedResidentialZone != null &&
      _selectedLanguage != null &&
      _selectedMaritalStatus != null &&
      _selectedGender != null;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2017),
      locale: Locale('es')
    );
    if (picked != null) {
      setState(() {
        dateController.text = picked
            .toIso8601String()
            .split("T")[0]
            .split("-")
            .reversed
            .join("/");
      });
    }
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
                      Navigator.of(context).pop();
                      context.go(widget.edit ? '/dashboard' : '/presentation');
                    });
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
                "Datos Personales",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AllowedColors.black,
                ),
              ),
              Text(
                  "Por favor, completa los siguientes campos con información válida",
                  style: TextStyle(
                    fontSize: 13,
                    color: AllowedColors.black,
                  )),
              const SizedBox(height: 20),

              // Fecha de nacimiento
              buildLabel("Fecha de nacimiento*"),
              TextFormField(
                controller: dateController,
                validator: (value) {
                  if (value?.isEmpty ?? false) {
                    return 'Campo obligatorio';
                  }
                  return null;
                },
                style: TextStyle(fontSize: 15, color: AllowedColors.black),
                decoration: inputDecoration('dd/MM/yyyy', isCalendar: true),
                readOnly: true,
                onTap: () {
                  _selectDate(context);
                },
              ),

              const SizedBox(height: 20),

              // País de Nacimiento
              buildLabel("País de Nacimiento*"),
              buildDropdown(_countries, _selectedCountry, (newValue) {
                setState(() {
                  _selectedCountry = newValue;
                });
              }, 'Seleccione su país de origen', requiredInput: true),

              const SizedBox(height: 20),

              // Zona residencial
              buildLabel("Zona Residencial*"),
              buildDropdown(_residentialZones, _selectedResidentialZone, (newValue) {
                setState(() {
                  _selectedResidentialZone = newValue;
                });
              }, 'Elija una opción', requiredInput: true),
              
              const SizedBox(height: 20),

              // Lengua materna
              buildLabel("Lengua Materna*"),
              buildDropdown(_languages, _selectedLanguage, (newValue) {
                setState(() {
                  _selectedLanguage = newValue;
                });
              }, 'Elija una opción', requiredInput: true),

              const SizedBox(height: 20),

              // Estado civil
              buildLabel("Estado Civil*"),
              buildDropdown(_maritalStatusOptions, _selectedMaritalStatus,
                  (newValue) {
                setState(() {
                  _selectedMaritalStatus = newValue;
                });
              }, 'Elija una opción', requiredInput: true),

              const SizedBox(height: 20),

              // Sexo
              buildLabel("Sexo*"),
              buildDropdown(_genders, _selectedGender, (newValue) {
                setState(() {
                  _selectedGender = newValue;
                });
              }, 'Elija una opción', requiredInput: true),

              const SizedBox(height: 30),

              // Botón de continuar
              CustomButton(
                  color: _isFormValid ? AllowedColors.blue : AllowedColors.gray,
                  onPressed: _isFormValid ? () {
                    if (_formKey.currentState?.validate() ?? false) {
                      User user = User.getCurrentUser();
                      if (widget.edit) {
                        UserRequest.setUserRequest(UserRequest(
                            "",
                            "",
                            "",
                            true,
                            PacienteRequest(
                                user.nombre,
                                dateController.text,
                                _selectedCountry!,
                                _selectedResidentialZone!,
                                _selectedLanguage!,
                                _selectedMaritalStatus!,
                                _selectedGender!,
                                widget.pacienteRequest!.infoSocioeconomica)));
                      } else {
                        UserRequest.setUserRequest(UserRequest(
                            user.nombreUsuario,
                            user.contrasena,
                            "USER",
                            false,
                            PacienteRequest(
                                user.nombre,
                                dateController.text,
                                _selectedCountry!,
                                _selectedResidentialZone!,
                                _selectedLanguage!,
                                _selectedMaritalStatus!,
                                _selectedGender!,
                                null)));
                      }

                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SocioeconomicInformation(
                                    infoSocioeconomicaRequest: widget
                                        .pacienteRequest?.infoSocioeconomica,
                                    edit: widget.edit,
                                  )));
                    }
                  } : null,
                  label: "Continuar")
            ],
          ),
        ),
      ),
    );
  }
}
