import 'package:chatbot/router.dart';
import 'package:chatbot/service/firebase_messaging_handler.dart';
import 'package:chatbot/utils/app_usage_tracker.dart';
import 'package:chatbot/view/widgets/utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'log_utils.dart';

Future<void> main() async {
  initializeLogger();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseMessaging.instance.requestPermission();
  await FirebaseMessagingHandler.initializeFCM();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      builder: (context, child) =>
          AppUsageTracker(child: child ?? const SizedBox.shrink()),
      debugShowCheckedModeBanner: false,
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale("es", "EC"),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AllowedColors.blue,
        fontFamily: "ArialNarrow",
      ),
    );
  }
}
