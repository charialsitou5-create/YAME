import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';

class DispatchResponseException implements Exception {
  DispatchResponseException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Répond (accepter/refuser) à une offre de course reçue du dispatch
/// serveur — voir `yame-admin/app/api/rides/respond`. Le chauffeur n'écrit
/// plus jamais lui-même status/driverUid sur ride_requests.
class DispatchResponseService {
  DispatchResponseService._();

  static Future<void> respond({required String rideId, required bool accept}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw DispatchResponseException('Vous devez être connecté.');
    }
    final idToken = await user.getIdToken();

    final response = await http.post(
      Uri.parse('${AppConfig.adminApiBaseUrl}/api/rides/respond'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'rideId': rideId, 'accept': accept}),
    );

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 200 || body?['success'] != true) {
      throw DispatchResponseException(
        body?['error'] as String? ?? 'Réponse impossible, réessayez.',
      );
    }
  }
}
