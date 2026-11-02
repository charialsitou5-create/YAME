import 'package:flutter/foundation.dart';

import '../models/ride_request.dart';
import 'doc.dart';

/// Accès à `ride_requests` et `ride_messages`. Les transitions de course passent par des
/// fonctions Postgres (une par transition autorisée) : le client ne peut rien faire d'autre.
class RideRepository {
  RideRepository._();

  /// Pour les sous-classes de test (faux dépôts en mémoire).
  @protected
  RideRepository.forTesting();

  /// Remplace le dépôt réel dans les tests.
  @visibleForTesting
  static RideRepository? debugOverride;

  factory RideRepository() => debugOverride ?? RideRepository._();

  SupabaseClient get _db => supabase;

  Stream<Doc> watchRide(String? id) {
    if (id == null) return const Stream.empty();
    return _db
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((rows) => rows.isEmpty ? Doc(id) : Doc(id, rideRowToDoc(rows.first)));
  }

  /// Courses du client dont le statut est dans [statuses] (les plus récentes, au plus [limit]).
  Stream<DocList> watchClientRidesWithStatus(String clientUid, List<String> statuses, {int limit = 1}) => _db
          .from('ride_requests')
          .stream(primaryKey: ['id'])
          .eq('client_uid', clientUid)
          .map((rows) {
        final kept = rows.where((r) => statuses.contains(r['status'])).toList()
          ..sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
        return DocList([for (final r in kept.take(limit)) Doc(r['id'] as String, rideRowToDoc(r))]);
      });

  /// Course actuellement proposée (en recherche) au chauffeur [driverUid].
  Stream<DocList> watchOfferedRide(String driverUid) => _db
          .from('ride_requests')
          .stream(primaryKey: ['id'])
          .eq('offered_uid', driverUid)
          .map((rows) {
        final kept = rows.where((r) => r['status'] == RideStatus.searching.firestoreValue).take(1);
        return DocList([for (final r in kept) Doc(r['id'] as String, rideRowToDoc(r))]);
      });

  /// Crée la demande de course (et marque le client comme ayant une course active) ; renvoie son id.
  Future<String> createRequest({required Json data}) async {
    final pickup = data['pickup'] as Map;
    final destination = data['destination'] as Map;
    final id = await _db.rpc('create_ride', params: {
      'p_pickup_lat': pickup['lat'],
      'p_pickup_lng': pickup['lng'],
      'p_pickup_address': data['pickupAddress'],
      'p_destination_lat': destination['lat'],
      'p_destination_lng': destination['lng'],
      'p_destination_address': data['destinationAddress'],
      'p_vehicle_type': data['vehicleType'],
      'p_client_name': data['clientName'],
      'p_price': data['price'],
      'p_recipient_name': data['recipientName'],
      'p_recipient_phone': data['recipientPhone'],
      'p_recipient_instructions': data['recipientInstructions'],
      'p_contact_requester_instead': data['contactRequesterInstead'] == true,
    });
    return id as String;
  }

  /// Annule la course côté client et libère `client_active_ride_id`.
  Future<void> cancelByClient({required String rideId, required String reason, String? comment}) async {
    await _db.rpc('client_cancel_ride', params: {'p_ride_id': rideId, 'p_reason': reason, 'p_comment': comment});
  }

  /// Le chauffeur assigné fait avancer (ou termine/annule) sa course d'une étape ; la base libère
  /// les deux parties et révoque l'accès à la position quand la course se termine.
  Future<void> advance(String rideId, RideStatus status) async {
    await _db.rpc('driver_advance_ride', params: {'p_ride_id': rideId, 'p_new_status': status.firestoreValue});
  }

  Future<void> rate(
    String rideId, {
    required int rating,
    String? comment,
    int? punctuality,
    int? driving,
    int? courtesy,
    int? cleanliness,
  }) async {
    await _db.rpc('rate_ride', params: {
      'p_ride_id': rideId,
      'p_rating': rating,
      'p_comment': comment,
      'p_punctuality': punctuality,
      'p_driving': driving,
      'p_courtesy': courtesy,
      'p_cleanliness': cleanliness,
    });
  }

  // ---------------------------------------------------------------- messages

  Stream<DocList> watchMessages(String rideId) => _db
      .from('ride_messages')
      .stream(primaryKey: ['id'])
      .eq('ride_id', rideId)
      .order('created_at', ascending: false)
      .map((rows) => DocList([for (final r in rows) Doc(r['id'] as String, messageRowToDoc(r))]));

  Future<void> sendMessage(String rideId, Json message) async {
    await _db.from('ride_messages').insert({
      'ride_id': rideId,
      'sender_uid': message['senderUid'],
      'type': message['type'],
      'text': message['text'],
      'location_address': message['locationAddress'],
      'latitude': message['latitude'],
      'longitude': message['longitude'],
    });
  }
}
