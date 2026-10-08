import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:yame/models/ride_request.dart';
import 'package:yame/models/vehicle_type.dart';

/// Cycle de vie d'une course vu par le modèle : mêmes transitions et mêmes
/// champs que ceux autorisés par firestore.rules (voir test-rules/).
void main() {
  late FakeFirebaseFirestore db;
  late DocumentReference<Map<String, dynamic>> ref;

  const request = RideRequest(
    clientUid: 'cli1',
    clientName: 'Client Test',
    pickup: LatLng(-4.78, 11.86),
    pickupAddress: 'Départ',
    destination: LatLng(-4.80, 11.88),
    destinationAddress: 'Arrivée',
    vehicleType: VehicleType.moto,
    status: RideStatus.searching,
    price: 1500,
  );

  Future<RideRequest> load() async => RideRequest.fromDoc(await ref.get());

  setUp(() async {
    db = FakeFirebaseFirestore();
    ref = db.collection('ride_requests').doc('r1');
    await ref.set(request.toMap());
  });

  test('création : demande en recherche, sans chauffeur ni offre', () async {
    final r = await load();
    expect(r.status, RideStatus.searching);
    expect(r.driverUid, isNull);
    expect(r.offeredUid, isNull);
    expect(r.vehicleType, VehicleType.moto);
    expect(r.price, 1500);
    expect(r.isForSomeoneElse, isFalse);
  });

  test('parcours complet : acceptée, arrivée, en cours, terminée, notée', () async {
    await ref.update({'status': 'accepted', 'driverUid': 'drv1', 'driverName': 'Paul'});
    var r = await load();
    expect(r.status, RideStatus.accepted);
    expect(r.driverUid, 'drv1');
    expect(r.driverName, 'Paul');

    await ref.update({'status': RideStatus.arrived.firestoreValue});
    expect((await load()).status, RideStatus.arrived);

    await ref.update({'status': RideStatus.inProgress.firestoreValue});
    expect((await load()).status, RideStatus.inProgress);

    await ref.update({'status': RideStatus.completed.firestoreValue});
    expect((await load()).status, RideStatus.completed);

    await ref.update({'rating': 5, 'ratingComment': 'Top'});
    final data = (await ref.get()).data()!;
    expect(data['rating'], 5);
    expect(data['ratingComment'], 'Top');
    r = await load();
    expect(r.status, RideStatus.completed, reason: 'noter ne change pas le statut');
    expect(r.driverUid, 'drv1');
  });

  test('annulation par le client avec motif', () async {
    await ref.update({'status': 'cancelled', 'cancelReason': 'changed_mind', 'cancelComment': 'RAS'});
    final r = await load();
    expect(r.status, RideStatus.cancelled);
    expect((await ref.get()).data()!['cancelReason'], 'changed_mind');
  });

  test('statut inconnu en base : retombe sur searching', () {
    expect(RideStatus.fromFirestoreValue('???'), RideStatus.searching);
  });

  test('chaque statut est relu à l\'identique depuis sa valeur Firestore', () {
    for (final s in RideStatus.values) {
      expect(RideStatus.fromFirestoreValue(s.firestoreValue), s);
    }
  });

  test('offre au chauffeur : offeredUid et expiration relus', () async {
    final expires = DateTime.utc(2026, 10, 8, 12);
    await ref.update({'offeredUid': 'drv9', 'offerExpiresAt': expires.toIso8601String()});
    final r = await load();
    expect(r.offeredUid, 'drv9');
    expect(r.offerExpiresAt, expires);
  });

  test('course pour un tiers : destinataire relu', () async {
    final other = RideRequest(
      clientUid: 'cli1',
      clientName: 'Client',
      pickup: request.pickup,
      pickupAddress: null,
      destination: request.destination,
      destinationAddress: null,
      vehicleType: VehicleType.car,
      status: RideStatus.searching,
      recipientName: 'Marie',
      recipientPhone: '060000000',
      contactRequesterInstead: true,
    );
    await db.collection('ride_requests').doc('r2').set(other.toMap());
    final r = RideRequest.fromDoc(await db.collection('ride_requests').doc('r2').get());
    expect(r.isForSomeoneElse, isTrue);
    expect(r.recipientName, 'Marie');
    expect(r.contactRequesterInstead, isTrue);
  });
}
