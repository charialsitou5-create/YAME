import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_repository.dart';

/// Accès Firestore à `ride_requests` (+ messages) et aux signalements.
class RideRepository {
  RideRepository([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Json> get _rides => _db.collection('ride_requests');

  /// Référence d'une course ; sans [id], un identifiant est généré.
  DocumentReference<Json> rideRef([String? id]) => id == null ? _rides.doc() : _rides.doc(id);

  CollectionReference<Json> messages(String rideId) => rideRef(rideId).collection('messages');

  Stream<DocumentSnapshot<Json>> watchRide(String id) => rideRef(id).snapshots();

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

  WriteBatch batch() => _db.batch();

  Future<void> addIncident(Json data) => _db.collection('incidents').add(data);
}
