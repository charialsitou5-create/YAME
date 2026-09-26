import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yame/features/driver/driver_home_screen.dart';
import 'package:yame/models/vehicle_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  for (final size in [const Size(360, 640), const Size(320, 480), const Size(411, 890)]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('driver home (hors ligne) ${size.width}x${size.height} x$scale', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const DriverHomeScreen(vehicleType: VehicleType.car, driverName: 'Test'),
        ));
        await t.pump(const Duration(milliseconds: 500));
        expect(t.takeException(), isNull);
      });
    }
  }
}
