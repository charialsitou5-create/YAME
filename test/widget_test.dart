import 'package:flutter_test/flutter_test.dart';

import 'package:yame/app.dart';
import 'package:yame/core/constants/app_strings.dart';

void main() {
  testWidgets('L\'accueil affiche le nom, le slogan et les profils', (tester) async {
    await tester.pumpWidget(const YameApp());

    expect(find.textContaining(AppStrings.appName), findsWidgets);
    expect(find.text(AppStrings.slogan), findsOneWidget);
    expect(find.text(AppStrings.roleClient), findsOneWidget);
    expect(find.text(AppStrings.roleDriverCar), findsOneWidget);
    expect(find.text(AppStrings.roleDriverMoto), findsOneWidget);
  });

  testWidgets('Choisir "Client" mène à l\'écran d\'inscription', (tester) async {
    await tester.pumpWidget(const YameApp());

    await tester.tap(find.text(AppStrings.roleClient));
    await tester.pumpAndSettle();

    expect(find.textContaining(AppStrings.signupHeadline), findsOneWidget);
    expect(find.text(AppStrings.fieldName), findsOneWidget);
  });
}
