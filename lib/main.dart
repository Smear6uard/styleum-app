import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/screens/auth/login_screen.dart';
import 'package:styleum/screens/main/main_screen.dart';
import 'package:styleum/screens/splash/splash_screen.dart';
import 'package:styleum/services/auth_service.dart';
import 'package:styleum/theme/theme.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.slate),
        useMaterial3: true,
      ),
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/login':
            page = const LoginScreen();
            break;
          case '/main':
            page = const MainScreen();
            break;
          default:
            page = const SplashScreen();
        }
        return AppPageRoute(page: page);
      },
      home: const SplashScreen(),
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
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.slate),
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
