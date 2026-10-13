import 'package:flutter_test/flutter_test.dart';
import 'package:yame/services/email_verification_service.dart';
import 'package:yame/services/event_logger.dart';

void main() {
  tearDown(() {
    AppEventLogger.resetForTest();
    AuthPolicy.setForTest(null);
  });

  group('authEventFor', () {
    test('inscription avec e-mail déjà pris', () {
      expect(authEventFor('signup', 'email-already-in-use'), 'signup_email_in_use');
      expect(authEventFor('signup', 'weak-password'), 'signup_failed');
    });
    test('connexion', () {
      expect(authEventFor('login', 'user-not-found'), 'login_unknown_account');
      expect(authEventFor('login', 'wrong-password'), 'login_wrong_password');
      expect(authEventFor('login', 'invalid-credential'), 'login_wrong_password');
      expect(authEventFor('login', 'too-many-requests'), 'login_too_many_attempts');
      expect(authEventFor('login', 'user-disabled'), 'login_account_disabled');
      expect(authEventFor('login', 'autre'), 'login_failed');
    });
    test('social et réinitialisation', () {
      expect(authEventFor('social', 'x'), 'social_login_failed');
      expect(authEventFor('reset', 'x'), 'password_reset_failed');
    });
  });

  group('AppEventLogger', () {
    test('envoie l\'événement avec plateforme et version', () async {
      final sent = <Map<String, Object?>>[];
      AppEventLogger.senderOverride = (p) async => sent.add(p);
      AppEventLogger.log('signup_email_in_use', code: 'email-already-in-use', email: 'a@b.cd', screen: 'signup');
      await Future<void>.delayed(Duration.zero);
      expect(sent, hasLength(1));
      expect(sent.single['event'], 'signup_email_in_use');
      expect(sent.single['email'], 'a@b.cd');
      expect(sent.single['appVersion'], isNotNull);
    });
    test('omet les champs vides', () async {
      final sent = <Map<String, Object?>>[];
      AppEventLogger.senderOverride = (p) async => sent.add(p);
      AppEventLogger.log('app_error', email: '');
      await Future<void>.delayed(Duration.zero);
      expect(sent.single.containsKey('email'), isFalse);
      expect(sent.single.containsKey('code'), isFalse);
    });
    test('un envoi qui échoue ne lève jamais', () async {
      AppEventLogger.senderOverride = (_) async => throw Exception('réseau');
      AppEventLogger.log('app_error');
      await Future<void>.delayed(Duration.zero);
    });
    test('plafonné par session', () async {
      var n = 0;
      AppEventLogger.senderOverride = (_) async => n++;
      for (var i = 0; i < 100; i++) {
        AppEventLogger.log('app_error');
      }
      await Future<void>.delayed(Duration.zero);
      expect(n, 60);
    });
  });

  group('AuthPolicy', () {
    test('sans valeur distante, retombe sur AppConfig (désactivé)', () {
      expect(AuthPolicy.requireVerifiedEmail, isFalse);
    });
    test('la valeur distante prime', () {
      AuthPolicy.setForTest(true);
      expect(AuthPolicy.requireVerifiedEmail, isTrue);
    });
  });
}
