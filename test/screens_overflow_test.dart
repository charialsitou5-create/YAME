import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yame/features/driver/driver_intro_screen.dart';
import 'package:yame/features/onboarding/onboarding_screen.dart';
import 'package:yame/models/vehicle_type.dart';

void main() {
  final sizes = {
    '360x640': const Size(360, 640),
    '320x480': const Size(320, 480),
  };
  final scales = [1.0, 1.3, 1.6];
  final screens = <String, Widget Function()>{
    'onboarding': () => const OnboardingScreen(),
    'driver_intro': () => const DriverIntroScreen(vehicleType: VehicleType.car),
  };

  for (final s in screens.entries) {
    for (final sz in sizes.entries) {
      for (final scale in scales) {
        testWidgets('${s.key} no overflow ${sz.key} x$scale', (t) async {
          t.view.physicalSize = sz.value;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await t.pumpWidget(MaterialApp(
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: s.value(),
          ));
          await t.pump(const Duration(milliseconds: 500));
          expect(t.takeException(), isNull);
        });
      }
    }
  }
}
