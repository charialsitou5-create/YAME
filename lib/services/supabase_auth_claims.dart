import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';

/// Fournit à Supabase le jeton Firebase de l'utilisateur. Supabase (auth tierce) exige la mention
/// `role: "authenticated"` dans le jeton : si elle manque (compte tout juste créé), le serveur l'ajoute
/// (`/api/auth/supabase-claims`) puis le jeton est rafraîchi.
class SupabaseAuthClaims {
  SupabaseAuthClaims._();

  static Future<String?>? _inFlight;

  static Future<String?> accessToken() {
    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  static Future<String?> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    var result = await user.getIdTokenResult();
    if (result.claims?['role'] != 'authenticated') {
      try {
        final response = await http.post(
          Uri.parse('${AppConfig.adminApiBaseUrl}/api/auth/supabase-claims'),
          headers: {'Authorization': 'Bearer ${result.token}', 'Content-Type': 'application/json'},
          body: jsonEncode({}),
        );
        if (response.statusCode == 200) result = await user.getIdTokenResult(true);
      } catch (_) {
        // Hors ligne : on renvoie le jeton tel quel, la requête échouera proprement.
      }
    }
    return result.token;
  }
}
