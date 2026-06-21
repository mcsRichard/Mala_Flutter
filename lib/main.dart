import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'services/reminder_service.dart';
import 'ui/auth/auth_screen.dart';
import 'ui/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await ReminderService.initialize();
  runApp(const MalaApp());
}

class MalaApp extends StatelessWidget {
  const MalaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mala',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B4513)),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) return const MainScreen();
          return const AuthScreen();
        },
      ),
    );
  }
}
