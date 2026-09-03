import 'package:chatbot/app_keys.dart';
import 'package:chatbot/model/requests/paciente_request.dart';
import 'package:chatbot/utils/dashboard_listener.dart';
import 'package:chatbot/view/screens/about_us.dart';
import 'package:chatbot/view/screens/dashboard.dart';
import 'package:chatbot/view/screens/encuesta_sus.dart';
import 'package:chatbot/view/screens/login.dart';
import 'package:chatbot/view/screens/password.dart';
import 'package:chatbot/view/screens/personal_data_form.dart';
import 'package:chatbot/view/screens/presentation.dart';
import 'package:chatbot/view/screens/register.dart';
import 'package:chatbot/view/screens/requiredSocioeconomicForm.dart';
import 'package:chatbot/view/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final router = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/presentation',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const Presentation(),
        transitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: child,
          );
        },
      ),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const Login(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => Register(),
    ),
    GoRoute(
      path: '/password',
      builder: (context, state) => const Password(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) {
        final offline = state.uri.queryParameters['offline'] == 'true';
        return DashboardListener(
          wasOffline: offline,
          child: Dashboard(
            key: Dashboard.globalKey,
            hasInternet: !offline,
          ),
        );
      },
    ),
    GoRoute(
      path: '/personal-data',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return PersonalDataForm(
          pacienteRequest: extra?['paciente'] as PacienteRequest?,
          edit: extra?['edit'] as bool? ?? false,
        );
      },
    ),
    GoRoute(
      path: '/required-socioeconomic',
      builder: (context, state) => RequiredSocioeconomicForm(
        paciente: state.extra as PacienteRequest,
      ),
    ),
    GoRoute(
      path: '/encuesta',
      builder: (context, state) => LikertSurveyPage(),
    ),
    GoRoute(
      path: '/about-us',
      builder: (context, state) => const AboutUs(),
    ),
  ],
);
