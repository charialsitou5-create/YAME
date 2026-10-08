import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_repository.dart';

/// Accès Firestore à la configuration `app_config/*`.
class ConfigRepository {
  ConfigRepository([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<DocumentSnapshot<Json>> getPricing() =>
      _db.collection('app_config').doc('pricing').get();
}
