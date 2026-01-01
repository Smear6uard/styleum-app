import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static const String _iosClientId =
      '642816391624-9f84235tn3aimlhekvo0tcgteh7m5mp2.apps.googleusercontent.com';

  SupabaseClient get _supabase => Supabase.instance.client;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: _iosClientId,
  );

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  User? getCurrentUser() => _supabase.auth.currentUser;

  Future<AuthResponse> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google Sign In was cancelled');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception('No ID token received from Google');
    }

    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    return response;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _supabase.auth.signOut();
  }
}
