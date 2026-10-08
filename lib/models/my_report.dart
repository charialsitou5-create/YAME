/// Résumé local d'un signalement, conservé dans `users/{uid}.myReports`.
///
/// Depuis le durcissement des règles, `incidents/{id}` n'est plus lisible par
/// l'app (il contient des notes internes) : seuls les messages de
/// `incidents/{id}/replies` le sont. L'app mémorise donc elle-même l'id et un
/// résumé de chaque signalement envoyé.
class MyReport {
  const MyReport({
    required this.id,
    required this.kind,
    required this.category,
    required this.message,
    this.createdAt,
  });

  static const maxStored = 50;
  static const maxMessageLength = 500;

  final String id;
  final String kind; // incident | feedback
  final String category;
  final String message;
  final DateTime? createdAt;

  factory MyReport.fromMap(Map<String, dynamic> m) => MyReport(
        id: m['id'] as String? ?? '',
        kind: m['kind'] as String? ?? 'incident',
        category: m['category'] as String? ?? '',
        message: m['message'] as String? ?? '',
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? ''),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind,
        'category': category,
        'message': message.length > maxMessageLength
            ? message.substring(0, maxMessageLength)
            : message,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  /// Lit `myReports` d'un document utilisateur (tolérant : ignore les
  /// entrées invalides), du plus récent au plus ancien.
  static List<MyReport> listFromUserData(Map<String, dynamic>? data) {
    final raw = data?['myReports'];
    if (raw is! List) return const [];
    final list = <MyReport>[
      for (final e in raw)
        if (e is Map && e['id'] is String && (e['id'] as String).isNotEmpty)
          MyReport.fromMap(Map<String, dynamic>.from(e)),
    ];
    list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }
}

/// Réponse de l'équipe (`incidents/{id}/replies/{rid}`).
class IncidentReply {
  const IncidentReply({required this.id, required this.text, this.createdAt});

  final String id;
  final String text;
  final DateTime? createdAt;

  factory IncidentReply.fromMap(String id, Map<String, dynamic> m) {
    final c = m['createdAt'];
    DateTime? date;
    if (c is String) {
      date = DateTime.tryParse(c);
    } else {
      try {
        final d = (c as dynamic).toDate();
        if (d is DateTime) date = d;
      } catch (_) {}
    }
    return IncidentReply(id: id, text: m['text'] as String? ?? '', createdAt: date);
  }
}
