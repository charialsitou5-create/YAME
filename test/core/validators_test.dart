import 'package:flutter_test/flutter_test.dart';
import 'package:yame/core/validators.dart';

void main() {
  group('normalizeCongoPhone', () {
    test('accepte et normalise les formats congolais', () {
      expect(normalizeCongoPhone('06 123 45 67'), '+242061234567');
      expect(normalizeCongoPhone('+242 06 123 45 67'), '+242061234567');
      expect(normalizeCongoPhone('00242051234567'), '+242051234567');
    });
    test('refuse le reste', () {
      for (final p in ['', '06 123 45', '+243 812 345 678', '07 123 45 67', '06abc4567', '61234567']) {
        expect(normalizeCongoPhone(p), isNull, reason: p);
      }
      expect(normalizeCongoPhone(null), isNull);
    });
  });

  group('plaques', () {
    test('normalise', () => expect(normalizePlate(' 271 kx-4 '), '271KX4'));
    test('plaque normale', () {
      expect(isPlausiblePlate('271 KX 4'), isTrue);
      expect(isPlausiblePlate('512 RG 4'), isTrue);
      expect(isPlausiblePlate('abc'), isFalse);
      expect(isPlausiblePlate('27 KX 4'), isFalse);
    });
    test('plaque spéciale plus souple', () {
      expect(isPlausiblePlate('CD 12 34', special: true), isTrue);
      expect(isPlausiblePlate('!!', special: true), isFalse);
    });
  });
}
