import 'package:chatbot/model/requests/user.dart';
import 'package:chatbot/model/storage/storage.dart';
import 'package:chatbot/service/auth_service.dart';
import 'package:chatbot/service/connectivity_service.dart';
import 'package:chatbot/view/widgets/utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

final _log = Logger('SplashScreen');

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), _checkAuth);
  }

  Future<void> _checkAuth() async {
    final hasInternet = await ConnectivityService.hasInternetConnection();
    final token = await secureStorage.read(key: "user_token");

    if (!hasInternet) {
      if (!mounted) return;
      if (token != null) {
        _log.fine("No internet — redirecting to dashboard offline.");
        context.go('/dashboard?offline=true');
      } else {
        context.push('/presentation');
      }
      return;
    }

    User? user = await User.loadUser();
    String? valid;

    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      valid = await AuthService.refreshToken(context, token);
    }

    if (!mounted) return;

    if (valid != null && user != null) {
      User.setCurrentUser(user, save: false);
      await secureStorage.write(key: "user_token", value: valid);
      _log.fine("Session valid — skipping login.");
      context.go('/dashboard');
    } else {
      _log.fine("No valid session — redirecting to presentation.");
      context.push('/presentation');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AllowedColors.white,
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 1000),
        opacity: _opacity,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/logo_ucuenca_top.png',
                        height: 100),
                    const SizedBox(height: 20),
                    Image.asset('assets/images/logo_clias.png', height: 80),
                    const SizedBox(height: 30),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    "VERSIÓN BETA",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AllowedColors.black,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
