import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';

enum MobileMoneyProvider { mtn, airtel }

extension MobileMoneyProviderApiValue on MobileMoneyProvider {
  String get apiValue => switch (this) {
        MobileMoneyProvider.mtn => 'mtn',
        MobileMoneyProvider.airtel => 'airtel',
      };
}

class RechargeException implements Exception {
  RechargeException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Initie une recharge Mobile Money (USSD Push) via le panneau admin, qui
/// contacte directement l'API MTN MoMo ou Airtel Money — voir
/// `yame-admin/app/api/recharge/initiate`. Le solde est crédité en
/// arrière-plan une fois le code PIN validé par le chauffeur ; l'écran de
/// recharge en est informé via le flux Firestore `wallet/current` déjà
/// affiché, pas par ce service.
class RechargeService {
  RechargeService._();

  static Future<String> initiate({
    required num amount,
    required String phoneNumber,
    required MobileMoneyProvider provider,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw RechargeException('Vous devez être connecté.');
    }
    final idToken = await user.getIdToken();

    final response = await http.post(
      Uri.parse('${AppConfig.adminApiBaseUrl}/api/recharge/initiate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'driverId': user.uid,
        'amount': amount,
        'phoneNumber': phoneNumber,
        'provider': provider.apiValue,
      }),
    );

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 200 || body?['success'] != true) {
      throw RechargeException(
        body?['error'] as String? ?? 'Recharge impossible, réessayez.',
      );
    }
    return body!['paymentReference'] as String;
  }
}
