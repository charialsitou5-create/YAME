import 'package:flutter/foundation.dart';

import 'doc.dart';

export 'doc.dart';

/// Colonnes de `users` modifiables par l'app (les champs de modération sont réservés à l'admin).
const _userColumns = {
  'name', 'phone', 'email', 'activeMode', 'driverVehicleType', 'vehicleRegistered',
  'clientActiveRideId', 'driverActiveRideId', 'fcmToken', 'myReports', 'createdAt',
};

/// Accès aux profils `users` et à la position temps réel du client.
class UserRepository {
  UserRepository._();

  /// Pour les sous-classes de test (faux dépôts en mémoire).
  @protected
  UserRepository.forTesting();

  /// Remplace le dépôt réel dans les tests.
  @visibleForTesting
  static UserRepository? debugOverride;

  factory UserRepository() => debugOverride ?? UserRepository._();

  SupabaseClient get _db => supabase;

  Stream<Doc> watchUser(String uid) => _db
      .from('users')
      .stream(primaryKey: ['uid'])
      .eq('uid', uid)
      .map((rows) => rows.isEmpty ? Doc(uid) : Doc(uid, rowToDoc(rows.first)));

  /// Profil + état « en ligne » (qui vit dans `driver_profiles`).
  Future<Doc> getUser(String uid) async {
    final row = await _db
        .from('users')
        .select('*, driver_profiles(driver_online)')
        .eq('uid', uid)
        .maybeSingle();
    if (row == null) return Doc(uid);
    final profile = row.remove('driver_profiles');
    final doc = rowToDoc(row);
    final online = profile is Map ? profile['driver_online'] : null;
    if (online is bool) doc['driverOnline'] = online;
    return Doc(uid, doc);
  }

  /// Crée (ou fusionne dans) le profil.
  Future<void> setUser(String uid, Json data) async {
    await _db.from('users').upsert({'uid': uid, ...docToRow(data, _userColumns)}, onConflict: 'uid');
  }

  /// Met à jour des champs ; `driverOnline` est redirigé vers `driver_profiles`.
  Future<void> updateUser(String uid, Json data) async {
    final row = docToRow(data, _userColumns);
    if (row.isNotEmpty) await _db.from('users').update(row).eq('uid', uid);
    if (data.containsKey('driverOnline')) {
      await _db.from('driver_profiles').update({'driver_online': data['driverOnline'] == true}).eq('uid', uid);
    }
  }

  Stream<Doc> watchClientLocation(String uid) =>
      _db
          .from('client_locations')
          .stream(primaryKey: ['client_uid'])
          .eq('client_uid', uid)
          .map((rows) => rows.isEmpty ? Doc(uid) : Doc(uid, rowToDoc(rows.first)));

  /// Retire l'accès du chauffeur à la position du client (fin de course).
  Future<void> clearActiveDriver(String uid) async {
    await _db.from('client_locations').update({'active_driver_uid': null}).eq('client_uid', uid);
  }

  /// Publie la position du client (n'écrase pas `active_driver_uid`, posé par le serveur).
  Future<void> publishClientLocation(String uid, double lat, double lng) async {
    await _db.from('client_locations').upsert(
      {'client_uid': uid, 'lat': lat, 'lng': lng, 'updated_at': nowIso()},
      onConflict: 'client_uid',
    );
  }
}
