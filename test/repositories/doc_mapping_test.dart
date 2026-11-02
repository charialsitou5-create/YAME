import 'package:flutter_test/flutter_test.dart';
import 'package:yame/repositories/doc.dart';

void main() {
  test('rowToDoc : camelCase, nuls omis, jsonb legacy fusionné', () {
    final doc = rowToDoc({
      'uid': 'u1',
      'active_mode': 'driver',
      'fcm_token': null,
      'legacy': {'role': 'x', 'ignored': null},
      'geo': 'POINT',
    });
    expect(doc, {'uid': 'u1', 'activeMode': 'driver', 'role': 'x'});
  });

  test('rideRowToDoc : pickup / destination imbriqués comme dans l\'ancien document', () {
    final doc = rideRowToDoc({
      'id': 'r1',
      'pickup_lat': -4.78,
      'pickup_lng': 11.86,
      'destination_lat': -4.8,
      'destination_lng': 11.88,
      'vehicle_type': 'car',
    });
    expect(doc['pickup'], {'lat': -4.78, 'lng': 11.86});
    expect(doc['destination'], {'lat': -4.8, 'lng': 11.88});
    expect(doc['vehicleType'], 'car');
    expect(doc.containsKey('pickupLat'), isFalse);
  });

  test('messageRowToDoc : created_at devient timestamp', () {
    final doc = messageRowToDoc({'id': 'm', 'sender_uid': 'u', 'created_at': '2026-11-01T10:00:00+00:00'});
    expect(doc['timestamp'], '2026-11-01T10:00:00+00:00');
    expect(doc['senderUid'], 'u');
  });

  test('docToRow : seules les colonnes autorisées, en snake_case ; null efface', () {
    final row = docToRow({'fcmToken': null, 'activeMode': 'client', 'lastTokenUpdate': 1}, {'fcmToken', 'activeMode'});
    expect(row, {'fcm_token': null, 'active_mode': 'client'});
  });

  test('toCamel / toSnake sont inverses sur les noms de colonnes', () {
    for (final c in ['driver_active_ride_id', 'rating_avg', 'uid']) {
      expect(toSnake(toCamel(c)), c);
    }
  });
}
