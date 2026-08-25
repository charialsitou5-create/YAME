import 'package:flutter_test/flutter_test.dart';

import 'package:yame/app.dart';
import 'package:yame/core/constants/app_strings.dart';

void main() {
  testWidgets('L\'onboarding affiche le nom et le slogan de Yame', (tester) async {
    await tester.pumpWidget(const YameApp());

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.slogan), findsOneWidget);
    expect(find.text(AppStrings.onboardingCta), findsOneWidget);
  });

  testWidgets('Le bouton "Commencer" mène à la sélection de profil', (tester) async {
    await tester.pumpWidget(const YameApp());

    await tester.tap(find.text(AppStrings.onboardingCta));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.roleSelectionTitle), findsOneWidget);
    expect(find.text(AppStrings.roleClient), findsOneWidget);
    expect(find.text(AppStrings.roleDriverCar), findsOneWidget);
    expect(find.text(AppStrings.roleDriverMoto), findsOneWidget);
  });
}
