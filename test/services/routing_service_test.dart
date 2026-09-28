import 'package:flutter_test/flutter_test.dart';
import 'package:yame/services/routing_service.dart';

void main() {
  group('formatEta', () {
    test('formats under an hour as "X min"', () {
      expect(formatEta(const Duration(seconds: 240)), '4 min');
      expect(formatEta(const Duration(seconds: 30)), '1 min');
    });

    test('formats an hour or more as "XhYY"', () {
      expect(formatEta(const Duration(minutes: 65)), '1h05');
      expect(formatEta(const Duration(minutes: 125)), '2h05');
    });
  });

  group('RouteResult', () {
    test('duration rounds durationSeconds to the nearest second', () {
      const result = RouteResult(polyline: [], distanceMeters: 1000, durationSeconds: 239.6);
      expect(result.duration, const Duration(seconds: 240));
    });
  });
}
