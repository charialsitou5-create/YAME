import 'package:flutter/foundation.dart';

import '../models/my_report.dart';
import 'doc.dart';

/// Signalements de l'utilisateur et réponses de l'équipe.
///
/// `incidents` n'est pas lisible par l'app ; on lit uniquement `incident_replies`
/// (RLS : auteur du signalement) pour les ids mémorisés dans `users.my_reports`
/// (voir [MyReport]). La création passe par la fonction `submit_incident`, qui
/// mémorise aussi l'entrée dans `my_reports`.
class IncidentRepository {
  IncidentRepository._();

  /// Pour les sous-classes de test (faux dépôts en mémoire).
  @protected
  IncidentRepository.forTesting();

  /// Remplace le dépôt réel dans les tests.
  @visibleForTesting
  static IncidentRepository? debugOverride;

  factory IncidentRepository() => debugOverride ?? IncidentRepository._();

  SupabaseClient get _db => supabase;

  /// Fil complet des réponses, plus anciennes en premier.
  Stream<List<IncidentReply>> watchReplies(String incidentId) => _db
      .from('incident_replies')
      .stream(primaryKey: ['id'])
      .eq('incident_id', incidentId)
      .order('created_at', ascending: true)
      .map((rows) => [
            for (final r in rows) IncidentReply.fromMap(r['id'] as String, {...rowToDoc(r), 'createdAt': r['created_at']}),
          ]);

  /// Vrai dès qu'au moins une réponse existe (erreur de lecture = faux).
  Stream<bool> watchHasReply(String incidentId) => _db
      .from('incident_replies')
      .stream(primaryKey: ['id'])
      .eq('incident_id', incidentId)
      .map((rows) => rows.isNotEmpty)
      .handleError((_) {}, test: (_) => true);

  /// Enregistre un signalement et renvoie son id.
  Future<String> submit({
    required String kind,
    required String category,
    required String message,
    String? reporterRole,
    String? reporterName,
    String? rideId,
  }) async {
    final id = await _db.rpc('submit_incident', params: {
      'p_kind': kind,
      'p_category': category,
      'p_message': message,
      'p_reporter_role': reporterRole,
      'p_ride_id': rideId,
      'p_reporter_name': reporterName,
    });
    return id as String;
  }
}
