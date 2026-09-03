import 'package:chatbot/model/requests/user_request.dart';
import 'package:chatbot/model/responses/user_response.dart';
import 'package:chatbot/service/auth_service.dart';
import 'package:chatbot/utils/terms_conditions.dart';
import 'package:chatbot/view/widgets/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

class TermsAndConditions extends StatefulWidget {
  const TermsAndConditions({super.key});

  @override
  State<TermsAndConditions> createState() => _TermsAndConditionsPageState();
}

class _TermsAndConditionsPageState extends State<TermsAndConditions> {
  bool _acceptedTerms = false;

  void _submit() async {
    if (_acceptedTerms) {
      UserRequest? user = UserRequest.getUserRequest();

      if (user != null) {
        user.aceptaConsentimiento = true;

        final doneLoading = modalLoadingDialog(context: context);

        UserResponse? userLogged = await AuthService.signUp(context, user);

        doneLoading();

        if (userLogged != null) {
          if (!mounted) return;
          context.go('/dashboard');
        }
      } else {
        // TODO: Handle null case
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Debes aceptar los términos y condiciones")),
      );
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
                  message:
                      "¿Desea cancelar la creación de su cuenta? Se perderán todos los datos ingresados.",
                  onYes: () {
                    Navigator.of(context).pop(); // close confirmation dialog
                    context.go('/presentation'); // clear registration stack
                  },
                );
              },
              child: Text("Cancelar",
                  style: TextStyle(color: AllowedColors.red, fontSize: 12))),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "Consentimiento Informado",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AllowedColors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AllowedColors.gray, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Markdown(
                  data: TermsConditions.termsAndConditions,
                  styleSheet: MarkdownStyleSheet(
                    h2: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AllowedColors.black),
                    strong: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AllowedColors.black),
                    p: TextStyle(fontSize: 12, color: Colors.black87),
                    listBullet: TextStyle(fontSize: 12, color: Colors.black87),
                    tableBody: TextStyle(fontSize: 11, color: Colors.black87),
                    tableHead: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AllowedColors.black),
                    blockSpacing: 6,
                  ),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                    activeColor: AllowedColors.blue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Expanded(
                    child: Text(
                      "He leído y acepto el consentimiento informado.",
                      style: TextStyle(fontSize: 11, color: AllowedColors.black),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _acceptedTerms ? AllowedColors.blue : AllowedColors.gray,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _acceptedTerms ? _submit : null,
                child: Text(
                  "Aceptar y continuar",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AllowedColors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
