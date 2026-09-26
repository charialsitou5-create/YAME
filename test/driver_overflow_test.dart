import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yame/features/driver/driver_status_screen.dart';

void main() {
  for (final scale in [1.0, 1.6]) {
    testWidgets('status screen no overflow 320x480 scale $scale', (t) async {
      t.view.physicalSize = const Size(320, 480);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: const Size(320, 480), textScaler: TextScaler.linear(scale)),
          child: const DriverStatusScreen(rejected: false),
        ),
      ));
      expect(t.takeException(), isNull);
    });
  }
}
