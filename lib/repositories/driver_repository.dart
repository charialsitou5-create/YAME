import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_repository.dart';

/// Accès Firestore à `driver_profiles/{uid}` et ses sous-documents.
class DriverRepository {
  DriverRepository([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Json> profileRef(String uid) =>
      _db.collection('driver_profiles').doc(uid);

  /// `driver_profiles/{uid}/location/current` : position temps réel du chauffeur.
  DocumentReference<Json> locationRef(String uid) =>
      profileRef(uid).collection('location').doc('current');

  DocumentReference<Json> documentsRef(String uid) =>
      profileRef(uid).collection('documents').doc('current');

  Stream<DocumentSnapshot<Json>> watchProfile(String uid) => profileRef(uid).snapshots();

  Stream<DocumentSnapshot<Json>> watchLocation(String uid) => locationRef(uid).snapshots();

  Future<DocumentSnapshot<Json>> getProfile(String uid) => profileRef(uid).get();
}
