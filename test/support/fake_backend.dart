import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yame/models/my_report.dart';
import 'package:yame/models/ride_request.dart';
import 'package:yame/repositories/config_repository.dart';
import 'package:yame/repositories/doc.dart';
import 'package:yame/repositories/driver_repository.dart';
import 'package:yame/repositories/incident_repository.dart';
import 'package:yame/repositories/ride_repository.dart';
import 'package:yame/repositories/user_repository.dart';
import 'package:yame/repositories/wallet_repository.dart';

/// Base de données en mémoire qui remplace Supabase dans les tests : mêmes « documents » camelCase
/// que ceux produits par `rowToDoc`, et flux qui réémettent à chaque changement.
class FakeBackend {
  FakeBackend() {
    UserRepository.debugOverride = _FakeUsers(this);
    DriverRepository.debugOverride = _FakeDrivers(this);
    WalletRepository.debugOverride = _FakeWallets(this);
    RideRepository.debugOverride = _FakeRides(this);
    IncidentRepository.debugOverride = _FakeIncidents(this);
    ConfigRepository.debugOverride = _FakeConfig(this);
    addTearDown(dispose);
  }

  final users = <String, Json>{};
  final driverProfiles = <String, Json>{};
  final wallets = <String, Json>{};
  final driverLocations = <String, Json>{};
  final clientLocations = <String, Json>{};
  final rides = <String, Json>{};
  final messages = <String, List<Json>>{};
  final replies = <String, List<Json>>{};
  final config = <String, Json>{};
  final incidents = <Json>[];

  final _changes = StreamController<void>.broadcast(sync: true);
  var _seq = 0;

  String nextId(String prefix) => '$prefix${++_seq}';
  void notify() => _changes.add(null);

  Stream<T> watch<T>(T Function() read) {
    late StreamController<T> c;
    StreamSubscription<void>? sub;
    c = StreamController<T>(
      onListen: () {
        c.add(read());
        sub = _changes.stream.listen((_) => c.add(read()));
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  Doc doc(Map<String, Json> table, String id) => Doc(id, table[id] == null ? null : Json.from(table[id]!));

  void dispose() {
    UserRepository.debugOverride = null;
    DriverRepository.debugOverride = null;
    WalletRepository.debugOverride = null;
    RideRepository.debugOverride = null;
    IncidentRepository.debugOverride = null;
    ConfigRepository.debugOverride = null;
    _changes.close();
  }
}

class _FakeUsers extends UserRepository {
  _FakeUsers(this.b) : super.forTesting();
  final FakeBackend b;

  @override
  Stream<Doc> watchUser(String uid) => b.watch(() => b.doc(b.users, uid));

  @override
  Future<Doc> getUser(String uid) async {
    final d = b.doc(b.users, uid);
    final online = b.driverProfiles[uid]?['driverOnline'];
    if (d.exists && online is bool) return Doc(uid, {...d.data()!, 'driverOnline': online});
    return d;
  }

  @override
  Future<void> setUser(String uid, Json data) async {
    b.users[uid] = {...?b.users[uid], ...data};
    b.notify();
  }

  @override
  Future<void> updateUser(String uid, Json data) async {
    final rest = {...data}..remove('driverOnline');
    final user = b.users.putIfAbsent(uid, () => {});
    rest.forEach((k, v) => v == null ? user.remove(k) : user[k] = v);
    if (data.containsKey('driverOnline')) {
      b.driverProfiles.putIfAbsent(uid, () => {})['driverOnline'] = data['driverOnline'] == true;
    }
    b.notify();
  }

  @override
  Stream<Doc> watchClientLocation(String uid) => b.watch(() => b.doc(b.clientLocations, uid));

  @override
  Future<void> publishClientLocation(String uid, double lat, double lng) async {
    b.clientLocations[uid] = {...?b.clientLocations[uid], 'lat': lat, 'lng': lng};
    b.notify();
  }

  @override
  Future<void> clearActiveDriver(String uid) async {
    b.clientLocations[uid]?.remove('activeDriverUid');
    b.notify();
  }
}

class _FakeDrivers extends DriverRepository {
  _FakeDrivers(this.b) : super.forTesting();
  final FakeBackend b;

  @override
  Stream<Doc> watchProfile(String uid) => b.watch(() => b.doc(b.driverProfiles, uid));

  @override
  Future<Doc> getProfile(String uid) async => b.doc(b.driverProfiles, uid);

  @override
  Stream<Doc> watchLocation(String uid) => b.watch(() => b.doc(b.driverLocations, uid));

  @override
  Future<void> publishLocation(String uid, double lat, double lng, double? heading) async {
    b.driverLocations[uid] = {...?b.driverLocations[uid], 'lat': lat, 'lng': lng, 'heading': ?heading};
    b.notify();
  }

  @override
  Future<void> registerVehicle(String uid, Json vehicle, Json documents) async {
    b.driverProfiles[uid] = {...?b.driverProfiles[uid], ...vehicle};
    b.wallets.putIfAbsent(uid, () => {'balance': 0});
    b.notify();
  }

  @override
  Future<void> release(String uid) async {
    b.users[uid]?.remove('driverActiveRideId');
    b.driverLocations[uid]?.remove('activeClientUid');
    b.notify();
  }
}

class _FakeWallets extends WalletRepository {
  _FakeWallets(this.b) : super.forTesting();
  final FakeBackend b;

  @override
  Stream<Doc> watchWallet(String uid) => b.watch(() => b.doc(b.wallets, uid));

  @override
  Future<Doc> getWallet(String uid) async => b.doc(b.wallets, uid);
}

class _FakeRides extends RideRepository {
  _FakeRides(this.b) : super.forTesting();
  final FakeBackend b;

  @override
  Stream<Doc> watchRide(String? id) => id == null ? const Stream.empty() : b.watch(() => b.doc(b.rides, id));

  @override
  Stream<DocList> watchClientRidesWithStatus(String clientUid, List<String> statuses, {int limit = 1}) => b.watch(() {
        final kept = b.rides.entries
            .where((e) => e.value['clientUid'] == clientUid && statuses.contains(e.value['status']))
            .take(limit);
        return DocList([for (final e in kept) Doc(e.key, Json.from(e.value))]);
      });

  @override
  Stream<DocList> watchOfferedRide(String driverUid) => b.watch(() {
        final kept = b.rides.entries
            .where((e) => e.value['offeredUid'] == driverUid && e.value['status'] == RideStatus.searching.firestoreValue)
            .take(1);
        return DocList([for (final e in kept) Doc(e.key, Json.from(e.value))]);
      });

  @override
  Future<String> createRequest({required Json data}) async {
    final id = b.nextId('ride');
    final uid = data['clientUid'] as String;
    b.rides[id] = {...data, 'status': 'searching'};
    b.users.putIfAbsent(uid, () => {})['clientActiveRideId'] = id;
    b.notify();
    return id;
  }

  @override
  Future<void> cancelByClient({required String rideId, required String reason, String? comment}) async {
    final ride = b.rides[rideId]!;
    ride
      ..['status'] = RideStatus.cancelled.firestoreValue
      ..['cancelReason'] = reason;
    if (comment != null) ride['cancelComment'] = comment;
    b.users[ride['clientUid']]?.remove('clientActiveRideId');
    b.notify();
  }

  @override
  Future<void> advance(String rideId, RideStatus status) async {
    final ride = b.rides[rideId]!;
    ride['status'] = status.firestoreValue;
    if (status == RideStatus.completed || status == RideStatus.cancelled) {
      final driver = ride['driverUid'] as String?;
      if (driver != null) {
        b.users[driver]?.remove('driverActiveRideId');
        b.driverLocations[driver]?.remove('activeClientUid');
      }
      b.users[ride['clientUid']]?.remove('clientActiveRideId');
    }
    b.notify();
  }

  @override
  Future<void> rate(
    String rideId, {
    required int rating,
    String? comment,
    int? punctuality,
    int? driving,
    int? courtesy,
    int? cleanliness,
  }) async {
    final ride = b.rides[rideId]!;
    ride['rating'] = rating;
    if (comment != null) ride['ratingComment'] = comment;
    b.notify();
  }

  @override
  Stream<DocList> watchMessages(String rideId) => b.watch(
        () => DocList([
          for (final m in (b.messages[rideId] ?? const <Json>[]).reversed) Doc(m['id'] as String, Json.from(m)),
        ]),
      );

  @override
  Future<void> sendMessage(String rideId, Json message) async {
    (b.messages[rideId] ??= []).add({
      ...message,
      'id': b.nextId('msg'),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
    b.notify();
  }
}

class _FakeIncidents extends IncidentRepository {
  _FakeIncidents(this.b) : super.forTesting();
  final FakeBackend b;

  @override
  Stream<List<IncidentReply>> watchReplies(String incidentId) => b.watch(
        () => [
          for (final r in b.replies[incidentId] ?? const <Json>[]) IncidentReply.fromMap(r['id'] as String, r),
        ],
      );

  @override
  Stream<bool> watchHasReply(String incidentId) => b.watch(() => (b.replies[incidentId] ?? const []).isNotEmpty);

  @override
  Future<String> submit({
    required String kind,
    required String category,
    required String message,
    String? reporterRole,
    String? reporterName,
    String? rideId,
  }) async {
    final id = b.nextId('inc');
    b.incidents.add({'id': id, 'kind': kind, 'category': category, 'message': message, 'rideId': rideId});
    b.notify();
    return id;
  }
}

class _FakeConfig extends ConfigRepository {
  _FakeConfig(this.b) : super.forTesting();
  final FakeBackend b;

  @override
  Future<Doc> getPricing() async => b.doc(b.config, 'pricing');

  @override
  Future<Doc> getAuthPolicy() async => b.doc(b.config, 'auth');
}
