import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ride_request.dart';
import 'driver_repository.dart';
import 'user_repository.dart';

/// Accès Firestore à `ride_requests` (+ messages) et aux signalements.
class RideRepository {
  RideRepository([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Json> get _rides => _db.collection('ride_requests');

  /// Référence d'une course ; sans [id], un identifiant est généré.
  DocumentReference<Json> rideRef([String? id]) => id == null ? _rides.doc() : _rides.doc(id);

  CollectionReference<Json> messages(String? rideId) => rideRef(rideId).collection('messages');

  Stream<DocumentSnapshot<Json>> watchRide(String? id) => rideRef(id).snapshots();

  Future<void> updateRide(String id, Json data) => rideRef(id).update(data);

  /// Courses du client dont le statut est dans [statuses] (au plus [limit]).
  Stream<QuerySnapshot<Json>> watchClientRidesWithStatus(
    String clientUid,
    List<String> statuses, {
    int limit = 1,
  }) =>
      _rides
          .where('clientUid', isEqualTo: clientUid)
          .where('status', whereIn: statuses)
          .limit(limit)
          .snapshots();

  /// Course actuellement proposée (en recherche) au chauffeur [driverUid].
  Stream<QuerySnapshot<Json>> watchOfferedRide(String driverUid) => _rides
      .where('offeredUid', isEqualTo: driverUid)
      .where('status', isEqualTo: RideStatus.searching.firestoreValue)
      .limit(1)
      .snapshots();

  /// Libère le chauffeur : révoque l'accès du client à sa position live et
  /// vide `driverActiveRideId` (sans toucher au statut de la course).
  Future<void> releaseDriver(String driverUid) {
    final batch = _db.batch();
    _releaseDriverInto(batch, driverUid);
    return batch.commit();
  }

  /// Termine/annule la course [rideId] avec [status] puis libère le chauffeur
  /// [driverUid] (si connu), le tout dans un seul batch.
  Future<void> finishRide({
    required String rideId,
    required RideStatus status,
    String? driverUid,
  }) {
    final batch = _db.batch()
      ..update(rideRef(rideId), {'status': status.firestoreValue});
    if (driverUid != null) _releaseDriverInto(batch, driverUid);
    return batch.commit();
  }

  void _releaseDriverInto(WriteBatch batch, String driverUid) {
    batch.set(
      DriverRepository(_db).locationRef(driverUid),
      {'activeClientUid': FieldValue.delete()},
      SetOptions(merge: true),
    );
    batch.update(UserRepository(_db).userRef(driverUid), {'driverActiveRideId': null});
  }

  WriteBatch batch() => _db.batch();

  Future<void> addIncident(Json data) => _db.collection('incidents').add(data);
}
