import 'package:flutter/foundation.dart';

import 'doc.dart';

/// Accès en lecture au portefeuille chauffeur `driver_wallets` (les écritures passent par le serveur).
class WalletRepository {
  WalletRepository._();

  /// Pour les sous-classes de test (faux dépôts en mémoire).
  @protected
  WalletRepository.forTesting();

  /// Remplace le dépôt réel dans les tests.
  @visibleForTesting
  static WalletRepository? debugOverride;

  factory WalletRepository() => debugOverride ?? WalletRepository._();

  SupabaseClient get _db => supabase;

  Stream<Doc> watchWallet(String uid) => _db
      .from('driver_wallets')
      .stream(primaryKey: ['driver_uid'])
      .eq('driver_uid', uid)
      .map((rows) => rows.isEmpty ? Doc(uid) : Doc(uid, rowToDoc(rows.first)));

  Future<Doc> getWallet(String uid) async {
    final row = await _db.from('driver_wallets').select().eq('driver_uid', uid).maybeSingle();
    return row == null ? Doc(uid) : Doc(uid, rowToDoc(row));
  }
}
