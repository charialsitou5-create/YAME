import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;

/// Accès Firestore aux documents `users/{uid}` (et leur sous-doc de position).
class UserRepository {
  UserRepository([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Json> userRef(String uid) => _db.collection('users').doc(uid);

  /// `users/{uid}/location/current` : position temps réel du client.
  DocumentReference<Json> clientLocationRef(String uid) =>
      userRef(uid).collection('location').doc('current');

  Stream<DocumentSnapshot<Json>> watchUser(String uid) => userRef(uid).snapshots();

  Future<DocumentSnapshot<Json>> getUser(String uid) => userRef(uid).get();

  Future<void> setUser(String uid, Json data) => userRef(uid).set(data);

  Future<void> updateUser(String uid, Json data) => userRef(uid).update(data);

  Stream<DocumentSnapshot<Json>> watchClientLocation(String uid) =>
      clientLocationRef(uid).snapshots();
}
