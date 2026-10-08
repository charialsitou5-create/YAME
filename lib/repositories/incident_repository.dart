import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/my_report.dart';
import 'user_repository.dart';

/// Signalements de l'utilisateur et réponses de l'équipe.
///
/// `incidents/{id}` n'est pas lisible par l'app ; on lit uniquement
/// `incidents/{id}/replies` (règle : auteur du signalement) pour les ids
/// mémorisés dans `users/{uid}.myReports` (voir [MyReport]).
class IncidentRepository {
  IncidentRepository([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Json> repliesRef(String incidentId) =>
      _db.collection('incidents').doc(incidentId).collection('replies');

  Query<Json> _repliesAsc(String incidentId) =>
      repliesRef(incidentId).orderBy('createdAt');

  /// Fil complet des réponses, plus anciennes en premier.
  Stream<List<IncidentReply>> watchReplies(String incidentId) =>
      _repliesAsc(incidentId).snapshots().map(
            (s) => [for (final d in s.docs) IncidentReply.fromMap(d.id, d.data())],
          );

  /// Vrai dès qu'au moins une réponse existe (erreur de lecture = faux).
  Stream<bool> watchHasReply(String incidentId) => repliesRef(incidentId)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isNotEmpty)
      .handleError((_) {}, test: (_) => true);

  /// Mémorise un signalement envoyé (les [MyReport.maxStored] plus récents).
  Future<void> rememberReport(String uid, MyReport report) async {
    final ref = UserRepository(_db).userRef(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = MyReport.listFromUserData(snap.data());
      final next = [report, ...current.where((r) => r.id != report.id)]
          .take(MyReport.maxStored)
          .map((r) => r.toMap())
          .toList();
      if (snap.exists) {
        tx.update(ref, {'myReports': next});
      } else {
        tx.set(ref, {'myReports': next});
      }
    });
  }
}
