import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yame/models/ride_request.dart';
import 'package:yame/repositories/config_repository.dart';
import 'package:yame/repositories/driver_repository.dart';
import 'package:yame/repositories/ride_repository.dart';
import 'package:yame/repositories/user_repository.dart';
import 'package:yame/repositories/wallet_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  test('UserRepository set/update/get/watch sur users/{uid}', () async {
    final repo = UserRepository(db);
    await repo.setUser('u1', {'name': 'A'});
    await repo.updateUser('u1', {'phone': '1'});
    final snap = await repo.getUser('u1');
    expect(snap.data(), {'name': 'A', 'phone': '1'});
    expect((await repo.watchUser('u1').first).data()?['name'], 'A');
    expect(repo.clientLocationRef('u1').path, 'users/u1/location/current');
  });

  test('DriverRepository chemins', () async {
    final repo = DriverRepository(db);
    expect(repo.profileRef('d').path, 'driver_profiles/d');
    expect(repo.locationRef('d').path, 'driver_profiles/d/location/current');
    expect(repo.documentsRef('d').path, 'driver_profiles/d/documents/current');
    await repo.profileRef('d').set({'status': 'approved'});
    expect((await repo.getProfile('d')).data()?['status'], 'approved');
  });

  test('WalletRepository lit driver_profiles/{uid}/wallet/current', () async {
    final repo = WalletRepository(db);
    await db.doc('driver_profiles/d/wallet/current').set({'balanceFcfa': 500});
    expect((await repo.getWallet('d')).data()?['balanceFcfa'], 500);
    expect((await repo.watchWallet('d').first).data()?['balanceFcfa'], 500);
  });

  test('RideRepository course, messages, filtre client, incidents', () async {
    final repo = RideRepository(db);
    final ref = repo.rideRef();
    await ref.set({'clientUid': 'c', 'status': 'accepted'});
    await repo.rideRef('other').set({'clientUid': 'c', 'status': 'completed'});
    await repo.updateRide(ref.id, {'rating': 5});
    expect((await repo.watchRide(ref.id).first).data()?['rating'], 5);
    final q = await repo.watchClientRidesWithStatus('c', ['accepted']).first;
    expect(q.docs.length, 1);
    expect(repo.messages('x').path, 'ride_requests/x/messages');
    final batch = repo.batch()..update(ref, {'status': 'arrived'});
    await batch.commit();
    expect((await ref.get()).data()?['status'], 'arrived');
    await repo.addIncident({'k': 1});
    expect((await db.collection('incidents').get()).docs.length, 1);
  });

  test('ConfigRepository lit app_config/pricing', () async {
    await db.doc('app_config/pricing').set({'car': {}});
    expect((await ConfigRepository(db).getPricing()).exists, isTrue);
  });

  test('RideRepository.finishRide et releaseDriver libèrent le chauffeur', () async {
    final repo = RideRepository(db);
    await db.doc('ride_requests/r1').set({'status': 'inProgress'});
    await db.doc('users/d1').set({'driverActiveRideId': 'r1'});
    await db.doc('driver_profiles/d1/location/current').set({'activeClientUid': 'c', 'lat': 1});
    await repo.finishRide(rideId: 'r1', status: RideStatus.completed, driverUid: 'd1');
    expect((await db.doc('ride_requests/r1').get()).data()?['status'], RideStatus.completed.firestoreValue);
    expect((await db.doc('users/d1').get()).data()?['driverActiveRideId'], isNull);
    final loc = (await db.doc('driver_profiles/d1/location/current').get()).data()!;
    expect(loc.containsKey('activeClientUid'), isFalse);
    expect(loc['lat'], 1);

    await db.doc('users/d1').update({'driverActiveRideId': 'r2'});
    await db.doc('driver_profiles/d1/location/current').update({'activeClientUid': 'c'});
    await repo.releaseDriver('d1');
    expect((await db.doc('users/d1').get()).data()?['driverActiveRideId'], isNull);
  });

  test('RideRepository.watchOfferedRide', () async {
    await db.doc('ride_requests/r1').set({'offeredUid': 'd', 'status': RideStatus.searching.firestoreValue});
    await db.doc('ride_requests/r2').set({'offeredUid': 'x', 'status': RideStatus.searching.firestoreValue});
    final q = await RideRepository(db).watchOfferedRide('d').first;
    expect(q.docs.map((d) => d.id), ['r1']);
  });

  test('RideRepository.createRequest puis cancelByClient', () async {
    final repo = RideRepository(db);
    await db.doc('users/c1').set({'name': 'C'});
    final id = await repo.createRequest(clientUid: 'c1', data: {'clientUid': 'c1', 'status': 'searching'});
    expect((await db.doc('users/c1').get()).data()?['clientActiveRideId'], id);
    expect((await db.doc('ride_requests/$id').get()).data()?['status'], 'searching');
    await repo.cancelByClient(rideId: id, clientUid: 'c1', reason: 'r', comment: 'x');
    final ride = (await db.doc('ride_requests/$id').get()).data()!;
    expect(ride['status'], RideStatus.cancelled.firestoreValue);
    expect(ride['cancelReason'], 'r');
    expect(ride['cancelComment'], 'x');
    expect((await db.doc('users/c1').get()).data()?['clientActiveRideId'], isNull);
  });
}
