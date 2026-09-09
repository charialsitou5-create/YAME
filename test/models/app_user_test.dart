import 'package:flutter_test/flutter_test.dart';
import 'package:yame/models/app_mode.dart';
import 'package:yame/models/app_user.dart';
import 'package:yame/models/vehicle_type.dart';

void main() {
  group('AppUser', () {
    test('fromMap defaults activeMode to client and driver fields to null when absent', () {
      final user = AppUser.fromMap('uid1', {'name': 'Test', 'phone': '060000000'});

      expect(user.activeMode, AppMode.client);
      expect(user.driverVehicleType, isNull);
      expect(user.clientActiveRideId, isNull);
      expect(user.driverActiveRideId, isNull);
    });

    test('toMap/fromMap round-trips activeMode and driverVehicleType for a driver account', () {
      const user = AppUser(
        uid: 'uid2',
        name: 'Chauffeur Test',
        phone: '061111111',
        activeMode: AppMode.driver,
        driverVehicleType: VehicleType.moto,
        vehicleRegistered: true,
      );

      final roundTripped = AppUser.fromMap('uid2', user.toMap());

      expect(roundTripped.activeMode, AppMode.driver);
      expect(roundTripped.driverVehicleType, VehicleType.moto);
      expect(roundTripped.vehicleRegistered, isTrue);
    });

    test('clientActiveRideId and driverActiveRideId are read straight from Firestore fields', () {
      final user = AppUser.fromMap('uid3', {
        'name': 'Client Test',
        'phone': '062222222',
        'clientActiveRideId': 'ride123',
      });

      expect(user.clientActiveRideId, 'ride123');
      expect(user.driverActiveRideId, isNull);
    });
  });
}
