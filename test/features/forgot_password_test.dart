import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yame/core/constants/app_strings.dart';
import 'package:yame/features/auth/forgot_password_screen.dart';

Widget _app(PasswordResetSender sender, {String email = ''}) => MaterialApp(
      home: ForgotPasswordScreen(sender: sender, initialEmail: email),
    );

Future<void> _submit(WidgetTester t, String email) async {
  await t.enterText(find.byType(TextFormField), email);
  await t.tap(find.text(AppStrings.forgotPasswordCta));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('succès : appelle le sender et affiche le message neutre', (t) async {
    String? sent;
    await t.pumpWidget(_app((e) async => sent = e));
    await _submit(t, ' a@b.cd ');
    expect(sent, 'a@b.cd');
    expect(find.text(AppStrings.forgotPasswordSuccess), findsOneWidget);
  });

  testWidgets('user-not-found : même message de succès (pas de fuite)', (t) async {
    await t.pumpWidget(_app((e) async => throw FirebaseAuthException(code: 'user-not-found')));
    await _submit(t, 'x@y.zz');
    expect(find.text(AppStrings.forgotPasswordSuccess), findsOneWidget);
  });

  testWidgets('invalid-email et too-many-requests : messages clairs', (t) async {
    await t.pumpWidget(_app((e) async => throw FirebaseAuthException(code: 'invalid-email')));
    await _submit(t, 'zz');
    expect(find.text(AppStrings.errorEmailInvalid), findsOneWidget);

    await t.pumpWidget(_app((e) async => throw FirebaseAuthException(code: 'too-many-requests')));
    await _submit(t, 'a@b.cd');
    expect(find.text(AppStrings.forgotPasswordTooManyRequests), findsOneWidget);
  });

  testWidgets('champ vide : validation, sender non appelé', (t) async {
    var called = false;
    await t.pumpWidget(_app((e) async => called = true));
    await t.tap(find.text(AppStrings.forgotPasswordCta));
    await t.pumpAndSettle();
    expect(called, isFalse);
    expect(find.text(AppStrings.errorRequired), findsOneWidget);
  });

  testWidgets('email pré-rempli depuis le login', (t) async {
    await t.pumpWidget(_app((e) async {}, email: 'pre@fill.io'));
    expect(find.text('pre@fill.io'), findsOneWidget);
  });

  testWidgets('erreur inconnue : message générique', (t) async {
    await t.pumpWidget(_app((e) async => throw StateError('boom')));
    await _submit(t, 'a@b.cd');
    expect(find.text(AppStrings.errorGeneric), findsOneWidget);
  });
}
