import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yame/features/driver/driver_intro_screen.dart';
import 'package:yame/features/driver/driver_shell.dart';
import 'package:yame/features/driver/driver_status_screen.dart';
import 'package:yame/features/home/profil_screen.dart';
import 'package:yame/models/vehicle_type.dart';

/// Régression : un chauffeur (approuvé, en attente ou pas encore inscrit)
/// doit toujours pouvoir atteindre `ProfilScreen` — seul endroit où vit le
/// bouton de bascule vers le mode Particulier — sans passer par la
/// déconnexion. Voir `_DriverSection._switchMode` dans `profil_screen.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('DriverShell exposes a Profil tab that opens ProfilScreen', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: DriverShell(vehicleType: VehicleType.car, driverName: 'Test'),
    ));
    await t.pump(const Duration(milliseconds: 500));

    final profileTab = find.widgetWithIcon(InkWell, Icons.person_outline_rounded);
    expect(profileTab, findsOneWidget);

    await t.tap(profileTab);
    await t.pumpAndSettle();

    expect(find.byType(ProfilScreen), findsOneWidget);
  });

  testWidgets('DriverStatusScreen exposes a Profil icon that opens ProfilScreen', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: DriverStatusScreen(rejected: false),
    ));
    await t.pump();

    final profileButton = find.widgetWithIcon(IconButton, Icons.person_outline_rounded);
    expect(profileButton, findsOneWidget);

    await t.tap(profileButton);
    await t.pumpAndSettle();

    expect(find.byType(ProfilScreen), findsOneWidget);
  });

  testWidgets('DriverIntroScreen exposes a Profil icon that opens ProfilScreen', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: DriverIntroScreen(vehicleType: VehicleType.car),
    ));
    await t.pump();

    final profileButton = find.widgetWithIcon(IconButton, Icons.person_outline_rounded);
    expect(profileButton, findsOneWidget);

    await t.tap(profileButton);
    await t.pumpAndSettle();

    expect(find.byType(ProfilScreen), findsOneWidget);
  });
}
