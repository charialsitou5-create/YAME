import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yame/core/constants/app_strings.dart';
import 'package:yame/features/onboarding/onboarding_screen.dart';
import 'package:yame/routes/app_routes.dart';

/// On teste directement l'OnboardingScreen : la route `/` réelle passe par
/// AuthGate, qui lit FirebaseAuth (indisponible sans Firebase initialisé).
Widget _app() => const MaterialApp(
      home: OnboardingScreen(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );

void main() {
  testWidgets('L\'accueil affiche le nom, le slogan et les profils', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.textContaining(AppStrings.appName), findsWidgets);
    expect(find.text(AppStrings.slogan), findsOneWidget);
    expect(find.text(AppStrings.roleClient), findsOneWidget);
    expect(find.text(AppStrings.roleDriverCar), findsOneWidget);
    expect(find.text(AppStrings.roleDriverMoto), findsOneWidget);
  });

  testWidgets('Choisir "Particulier" mène à l\'écran d\'inscription', (tester) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text(AppStrings.roleClient));
    await tester.pumpAndSettle();

    expect(find.textContaining(AppStrings.signupHeadline), findsOneWidget);
    expect(find.text(AppStrings.fieldName), findsOneWidget);
  });
}
