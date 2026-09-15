import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';

class DispatchException implements Exception {
  DispatchException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Déclenche le dispatch serveur d'une course tout juste créée — voir
/// `yame-admin/app/api/rides/dispatch` et
/// `docs/superpowers/specs/2026-09-12-ride-dispatch-design.md`.
class DispatchService {
  DispatchService._();

  static Future<void> start({required String rideId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw DispatchException('Vous devez être connecté.');
    }
    final idToken = await user.getIdToken();

    final response = await http.post(
      Uri.parse('${AppConfig.adminApiBaseUrl}/api/rides/dispatch'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'rideId': rideId}),
    );

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 200 || body?['success'] != true) {
      throw DispatchException(
        body?['error'] as String? ?? 'Impossible de lancer la recherche.',
      );
    }
  }
}
