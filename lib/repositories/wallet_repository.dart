import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_repository.dart';

/// Accès Firestore au portefeuille chauffeur `driver_profiles/{uid}/wallet/current`.
class WalletRepository {
  WalletRepository([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Json> walletRef(String uid) => _db
      .collection('driver_profiles')
      .doc(uid)
      .collection('wallet')
      .doc('current');

  Stream<DocumentSnapshot<Json>> watchWallet(String uid) => walletRef(uid).snapshots();

  Future<DocumentSnapshot<Json>> getWallet(String uid) => walletRef(uid).get();
}
