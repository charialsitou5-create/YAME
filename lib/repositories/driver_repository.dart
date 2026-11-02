import 'package:flutter/foundation.dart';

import 'doc.dart';

/// Colonnes de `driver_profiles` écrites par l'app (statut et notation : réservés à l'admin).
const _profileColumns = {'vehicleType', 'model', 'year', 'plate', 'seats', 'color', 'status', 'createdAt'};

/// Accès à `driver_profiles`, `driver_locations` et `driver_documents`.
class DriverRepository {
  DriverRepository._();

  /// Pour les sous-classes de test (faux dépôts en mémoire).
  @protected
  DriverRepository.forTesting();

  /// Remplace le dépôt réel dans les tests.
  @visibleForTesting
  static DriverRepository? debugOverride;

  factory DriverRepository() => debugOverride ?? DriverRepository._();

  SupabaseClient get _db => supabase;

  Stream<Doc> watchProfile(String uid) => _db
      .from('driver_profiles')
      .stream(primaryKey: ['uid'])
      .eq('uid', uid)
      .map((rows) => rows.isEmpty ? Doc(uid) : Doc(uid, rowToDoc(rows.first)));

  Future<Doc> getProfile(String uid) async {
    final row = await _db.from('driver_profiles').select().eq('uid', uid).maybeSingle();
    return row == null ? Doc(uid) : Doc(uid, rowToDoc(row));
  }

  /// Position live du chauffeur (lisible par le client de sa course active uniquement, via la RLS).
  Stream<Doc> watchLocation(String uid) => _db
      .from('driver_locations')
      .stream(primaryKey: ['driver_uid'])
      .eq('driver_uid', uid)
      .map((rows) => rows.isEmpty ? Doc(uid) : Doc(uid, rowToDoc(rows.first)));

  /// Publie la position (n'écrase pas `active_client_uid`, posé par le serveur).
  Future<void> publishLocation(String uid, double lat, double lng, double? heading) async {
    await _db.from('driver_locations').upsert(
      {'driver_uid': uid, 'lat': lat, 'lng': lng, 'heading': heading, 'updated_at': nowIso()},
      onConflict: 'driver_uid',
    );
  }

  /// Crée la fiche véhicule (statut `pending_verification`), le portefeuille à 0 et,
  /// s'il y en a, les documents d'identité — dans l'ordre imposé par les clés étrangères.
  Future<void> registerVehicle(String uid, Json vehicle, Json documents) async {
    await _db.from('driver_profiles').upsert({'uid': uid, ...docToRow(vehicle, _profileColumns)}, onConflict: 'uid');
    await _db.from('driver_wallets').upsert({'driver_uid': uid, 'balance': 0}, onConflict: 'driver_uid', ignoreDuplicates: true);
    if (documents.isNotEmpty) {
      await _db.from('driver_documents').upsert({
        'driver_uid': uid,
        if (documents['photoUrls'] != null) 'photo_urls': documents['photoUrls'],
        if (documents['registrationCardUrl'] != null) 'registration_card_url': documents['registrationCardUrl'],
        if (documents['licenseUrl'] != null) 'license_url': documents['licenseUrl'],
        'updated_at': nowIso(),
      }, onConflict: 'driver_uid');
    }
  }

  /// Libère le chauffeur : plus de course active ni de client autorisé à voir sa position.
  Future<void> release(String uid) async {
    await _db.from('users').update({'driver_active_ride_id': null}).eq('uid', uid);
    await _db.from('driver_locations').update({'active_client_uid': null}).eq('driver_uid', uid);
  }
}
