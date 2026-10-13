import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';

/// Envoi des événements (échecs de connexion/inscription, e-mails de
/// vérification, erreurs) au journal d'erreurs du panneau admin.
///
/// Ne lève jamais et n'attend jamais : un problème de journalisation ne doit
/// pas gêner l'utilisateur. L'e-mail est envoyé au serveur, qui n'en garde
/// qu'une version masquée et une empreinte.
class AppEventLogger {
  AppEventLogger._();

  static const _maxPerSession = 60;
  static int _sent = 0;

  /// Remplaçable dans les tests.
  @visibleForTesting
  static Future<void> Function(Map<String, Object?> payload)? senderOverride;

  static void log(
    String event, {
    String? code,
    String? message,
    String? email,
    String? screen,
  }) {
    if (_sent >= _maxPerSession) return;
    _sent++;
    final payload = <String, Object?>{
      'event': event,
      'code': ?code,
      'message': ?(message != null && message.length > 280 ? message.substring(0, 280) : message),
      'email': ?((email != null && email.isNotEmpty) ? email : null),
      'screen': ?screen,
      'platform': defaultTargetPlatform.name,
      'appVersion': AppConfig.appVersion,
    };
    if (kDebugMode) debugPrint('[AppEventLogger] $event ${code ?? ''}');
    unawaited(_send(payload));
  }

  static Future<void> _send(Map<String, Object?> payload) async {
    try {
      final override = senderOverride;
      if (override != null) {
        await override(payload);
        return;
      }
      final headers = <String, String>{'Content-Type': 'application/json'};
      try {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (token != null) headers['Authorization'] = 'Bearer $token';
      } catch (_) {}
      await http
          .post(
            Uri.parse('${AppConfig.adminApiBaseUrl}/api/logs/client'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Journaliser ne doit jamais casser l'app.
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _sent = 0;
    senderOverride = null;
  }
}

/// Événement à journaliser pour un échec d'authentification, selon l'écran
/// d'où il vient (`signup`, `login`, `social`, `reset`).
String authEventFor(String flow, String code) {
  switch (flow) {
    case 'signup':
      return code == 'email-already-in-use' ? 'signup_email_in_use' : 'signup_failed';
    case 'login':
      switch (code) {
        case 'user-not-found':
          return 'login_unknown_account';
        case 'wrong-password':
        case 'invalid-credential':
          return 'login_wrong_password';
        case 'too-many-requests':
          return 'login_too_many_attempts';
        case 'user-disabled':
          return 'login_account_disabled';
        default:
          return 'login_failed';
      }
    case 'social':
      return 'social_login_failed';
    case 'reset':
      return 'password_reset_failed';
    default:
      return 'app_error';
  }
}
