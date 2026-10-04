import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';

enum RidePaymentMethod { card, mobileMoney }

extension RidePaymentMethodApiValue on RidePaymentMethod {
  String get apiValue => switch (this) {
        RidePaymentMethod.card => 'card',
        RidePaymentMethod.mobileMoney => 'mobile_money',
      };
}

class RidePaymentException implements Exception {
  RidePaymentException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Paie une course terminée via `yame-admin` : le montant n'est jamais
/// envoyé par l'app, il est recalculé côté serveur à partir de la grille
/// tarifaire (voir `yame-admin/lib/services/ridePayment.ts`), qui crédite
/// aussi le chauffeur (montant total, la commission étant prélevée sur son solde de recharge à la fin de course) et verrouille la course comme
/// payée — plus jamais une écriture Firestore directe depuis le client.
class PaymentService {
  PaymentService._();

  static Future<int> pay({
    required String rideId,
    required RidePaymentMethod method,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw RidePaymentException('Vous devez être connecté.');
    }
    final idToken = await user.getIdToken();

    final response = await http.post(
      Uri.parse('${AppConfig.adminApiBaseUrl}/api/rides/pay'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'rideId': rideId, 'method': method.apiValue}),
    );

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 200 || body?['success'] != true) {
      throw RidePaymentException(
        body?['error'] as String? ?? 'Paiement impossible, réessayez.',
      );
    }
    return body!['amount'] as int;
  }

  /// Demande au serveur de prélever la commission sur le solde de recharge du
  /// chauffeur, une fois la course terminée — que le client paie en ligne ou
  /// en espèces. Idempotent côté serveur.
  static Future<void> chargeCommission({required String rideId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw RidePaymentException('Vous devez être connecté.');
    }
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse('${AppConfig.adminApiBaseUrl}/api/rides/commission'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'rideId': rideId}),
    );
    if (response.statusCode != 200) {
      throw RidePaymentException('Commission non prélevée.');
    }
  }
}
