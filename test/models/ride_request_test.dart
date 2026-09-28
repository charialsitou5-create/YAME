import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:yame/models/ride_request.dart';
import 'package:yame/models/vehicle_type.dart';

void main() {
  group('RideRequest.price', () {
    test('toMap/fromDoc round-trips the price quoted to the client at booking', () async {
      final db = FakeFirebaseFirestore();
      const request = RideRequest(
        clientUid: 'cli1',
        clientName: 'Client Test',
        pickup: LatLng(-4.78, 11.86),
        pickupAddress: 'Départ',
        destination: LatLng(-4.80, 11.88),
        destinationAddress: 'Arrivée',
        vehicleType: VehicleType.car,
        status: RideStatus.searching,
        price: 2500,
      );

      final ref = db.collection('ride_requests').doc('r1');
      await ref.set(request.toMap());
      final roundTripped = RideRequest.fromDoc(await ref.get());

      expect(roundTripped.price, 2500);
    });

    test('toMap omits price when null instead of writing a null field', () async {
      const request = RideRequest(
        clientUid: 'cli1',
        clientName: 'Client Test',
        pickup: LatLng(-4.78, 11.86),
        pickupAddress: null,
        destination: LatLng(-4.80, 11.88),
        destinationAddress: null,
        vehicleType: VehicleType.car,
        status: RideStatus.searching,
      );

      expect(request.toMap().containsKey('price'), isFalse);
    });

    test('fromDoc defaults price to null for a ride created before this field existed', () async {
      final db = FakeFirebaseFirestore();
      final ref = db.collection('ride_requests').doc('legacy');
      await ref.set({
        'clientUid': 'cli1',
        'clientName': 'Client Test',
        'pickup': {'lat': -4.78, 'lng': 11.86},
        'destination': {'lat': -4.80, 'lng': 11.88},
        'vehicleType': 'car',
        'status': 'searching',
      });

      final ride = RideRequest.fromDoc(await ref.get());

      expect(ride.price, isNull);
    });
  });
}
