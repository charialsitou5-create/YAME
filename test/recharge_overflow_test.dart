import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yame/features/driver/recharge_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  for (final size in [const Size(360, 640), const Size(320, 480)]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('recharge no overflow ${size.width}x${size.height} x$scale', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const RechargeScreen(),
        ));
        await t.pump(const Duration(milliseconds: 300));
        final ex = t.takeException();
        expect(ex is FlutterError && ex.toString().contains('overflowed'), isFalse, reason: '$ex');
      });
    }
  }
}
