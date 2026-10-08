/// Décision de modération côté app (confort UX : le serveur reste l'autorité,
/// il annule déjà les courses d'un client restreint).
enum ModerationKind { blocked, suspended }

class ModerationState {
  const ModerationState({required this.kind, this.until, this.reason});

  final ModerationKind kind;

  /// Fin de la suspension (`null` = durée indéterminée). Ignorée si bloqué.
  final DateTime? until;
  final String? reason;

  /// Client : lit `moderationStatus` / `moderationUntil` / `moderationReason`
  /// de `users/{uid}`. Retourne `null` si le compte est actif. Un statut
  /// inconnu ou absent est traité comme actif.
  static ModerationState? forClient(Map<String, dynamic>? userData, {DateTime? now}) {
    if (userData == null) return null;
    return _decide(
      status: userData['moderationStatus'],
      until: userData['moderationUntil'],
      reason: userData['moderationReason'],
      suspendedValue: 'suspended',
      now: now,
    );
  }

  /// Chauffeur : `driver_profiles/{uid}.status == 'suspended'` +
  /// `suspendedUntil` + `moderationReason`. Autres statuts (approved,
  /// pending_verification, rejected, inconnu) : pas de suspension.
  static ModerationState? forDriver(Map<String, dynamic>? profileData, {DateTime? now}) {
    if (profileData == null) return null;
    return _decide(
      status: profileData['status'],
      until: profileData['suspendedUntil'],
      reason: profileData['moderationReason'],
      suspendedValue: 'suspended',
      now: now,
    );
  }

  static ModerationState? _decide({
    required Object? status,
    required Object? until,
    required Object? reason,
    required String suspendedValue,
    DateTime? now,
  }) {
    final cleanReason = reason is String && reason.trim().isNotEmpty ? reason.trim() : null;
    if (status == 'blocked') {
      return ModerationState(kind: ModerationKind.blocked, reason: cleanReason);
    }
    if (status != suspendedValue) return null;
    final untilDate = _parseDate(until);
    if (untilDate != null && !untilDate.isAfter(now ?? DateTime.now())) {
      return null; // suspension échue
    }
    return ModerationState(
      kind: ModerationKind.suspended,
      until: untilDate,
      reason: cleanReason,
    );
  }

  static DateTime? _parseDate(Object? v) {
    if (v is String) return DateTime.tryParse(v);
    if (v is DateTime) return v;
    // Timestamp Firestore (toDate) sans dépendre du package ici.
    try {
      final d = (v as dynamic).toDate();
      if (d is DateTime) return d;
    } catch (_) {}
    return null;
  }
}
