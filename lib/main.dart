import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/screens/auth/login_screen.dart';
import 'package:styleum/screens/main/main_screen.dart';
import 'package:styleum/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ldfnbklxxeqhughckeus.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxkZm5ia2x4eGVxaHVnaGNrZXVzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzNzA4MTMsImV4cCI6MjA3OTk0NjgxM30.89LSDBgBn2TAXzroya2_1uBkZLxHpcwDvuiBwaoKsX8',
  );

  runApp(const StyleumApp());
}

class StyleumApp extends StatelessWidget {
  const StyleumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Styleum',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC4515E),
        ),
        useMaterial3: true,
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainScreen(),
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFFFFFFF),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFC4515E),
              ),
            ),
          );
        }

        final session = snapshot.data?.session;
        if (session != null) {
          return const MainScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

