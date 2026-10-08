import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yame/core/constants/app_config.dart';
import 'package:yame/core/constants/app_strings.dart';
import 'package:yame/core/widgets/email_verification_banner.dart';
import 'package:yame/services/email_verification_service.dart';

class _FakeSource implements EmailVerificationSource {
  _FakeSource({this.needs = true, this.verifiesOnReload = false});
  bool needs;
  bool verifiesOnReload;
  int resends = 0;
  @override
  bool get needsVerification => needs;
  @override
  Future<void> resend() async => resends++;
  @override
  Future<bool> reloadAndCheck() async {
    if (verifiesOnReload) needs = false;
    return !needs;
  }
}

Widget _app(EmailVerificationSource s) => MaterialApp(
      home: Scaffold(body: Column(children: [EmailVerificationBanner(source: s)])),
    );

void main() {
  group('logique', () {
    test('seuls les comptes mot de passe non vérifiés sont concernés', () {
      expect(emailNeedsVerification(emailVerified: false, providerIds: ['password']), isTrue);
      expect(emailNeedsVerification(emailVerified: true, providerIds: ['password']), isFalse);
      expect(emailNeedsVerification(emailVerified: false, providerIds: ['google.com']), isFalse);
      expect(emailNeedsVerification(emailVerified: false, providerIds: ['facebook.com']), isFalse);
      expect(emailNeedsVerification(emailVerified: false, providerIds: []), isFalse);
    });

    test('la porte ne bloque que si le drapeau est actif', () {
      expect(emailGateBlocks(requireVerifiedEmail: false, needsVerification: true), isFalse);
      expect(emailGateBlocks(requireVerifiedEmail: true, needsVerification: true), isTrue);
      expect(emailGateBlocks(requireVerifiedEmail: true, needsVerification: false), isFalse);
    });

    test('drapeau désactivé par défaut', () {
      expect(AppConfig.requireVerifiedEmail, isFalse);
      expect(emailVerificationBlocksAction(_FakeSource()), isFalse);
    });
  });

  group('bandeau', () {
    testWidgets('affiché pour un compte non vérifié, avec les deux actions', (t) async {
      await t.pumpWidget(_app(_FakeSource()));
      expect(find.text(AppStrings.emailVerifyBannerTitle), findsOneWidget);
      expect(find.text(AppStrings.emailVerifyResend), findsOneWidget);
      expect(find.text(AppStrings.emailVerifyDone), findsOneWidget);
    });

    testWidgets('absent pour un compte vérifié ou social', (t) async {
      await t.pumpWidget(_app(_FakeSource(needs: false)));
      expect(find.text(AppStrings.emailVerifyBannerTitle), findsNothing);
    });

    testWidgets('Renvoyer appelle resend', (t) async {
      final s = _FakeSource();
      await t.pumpWidget(_app(s));
      await t.tap(find.text(AppStrings.emailVerifyResend));
      await t.pumpAndSettle();
      expect(s.resends, 1);
      expect(find.text(AppStrings.emailVerifyResent), findsOneWidget);
    });

    testWidgets('J\'ai vérifié : encore non vérifié -> reste affiché', (t) async {
      await t.pumpWidget(_app(_FakeSource()));
      await t.tap(find.text(AppStrings.emailVerifyDone));
      await t.pumpAndSettle();
      expect(find.text(AppStrings.emailVerifyStillPending), findsOneWidget);
      expect(find.text(AppStrings.emailVerifyBannerTitle), findsOneWidget);
    });

    testWidgets('J\'ai vérifié : vérifié -> le bandeau disparaît', (t) async {
      await t.pumpWidget(_app(_FakeSource(verifiesOnReload: true)));
      await t.tap(find.text(AppStrings.emailVerifyDone));
      await t.pumpAndSettle();
      expect(find.text(AppStrings.emailVerifyBannerTitle), findsNothing);
    });
  });
}
