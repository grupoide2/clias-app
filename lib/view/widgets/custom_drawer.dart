import 'package:chatbot/model/requests/user.dart';
import 'package:chatbot/service/paciente_service.dart';
import 'package:chatbot/view/widgets/utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 280, // Ajusta el tamaño del drawer
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40), // Espaciado

          // Avatar del Usuario
          CircleAvatar(
            radius: 40,
            backgroundImage: AssetImage('assets/images/avatar.png'),
          ),
          const SizedBox(height: 10),
          Text(
            User.getCurrentUser().nombre,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AllowedColors.black),
          ),
          const SizedBox(height: 30),

          // Botones de Opciones
          _buildDrawerButton(Icons.person, "Perfil", () async {
            final pacienteRequest = await PacienteService.getPaciente(context);
            if (pacienteRequest == null || !context.mounted) return;
            Navigator.of(context).pop(); // close drawer
            context.push('/personal-data',
                extra: {'paciente': pacienteRequest, 'edit': true});
          }),
          _buildDrawerButton(Icons.info, "Acerca de", () {
            Navigator.of(context).pop(); // close drawer
            context.push('/about-us');
          }),

          const Spacer(), // Empuja el botón "Cerrar sesión" hacia abajo

          // Botón Cerrar Sesión
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AllowedColors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // close drawer
                  User.clear();
                  context.go('/presentation');
                },
                child: Text(
                  "Cerrar sesión",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AllowedColors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerButton(IconData icon, String label, VoidCallback? onTap) {
    return ListTile(
      leading: Icon(icon, color: AllowedColors.blue),
      title: Text(
        label,
        style: TextStyle(fontSize: 13),
      ),
      onTap: onTap,
    );
  }
}