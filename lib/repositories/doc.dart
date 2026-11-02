import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

typedef Json = Map<String, dynamic>;

/// Un « document » : une ligne Postgres exposée sous la forme camelCase que
/// l'app consommait déjà (hérité de Firestore), pour ne pas réécrire les écrans.
class Doc {
  const Doc(this.id, [this._data]);

  final String id;
  final Json? _data;

  bool get exists => _data != null;
  Json? data() => _data;
}

class DocList {
  const DocList(this.docs);

  final List<Doc> docs;
}

/// Client Supabase de l'app.
SupabaseClient get supabase => Supabase.instance.client;

String toCamel(String s) => s.replaceAllMapped(RegExp(r'_([a-z])'), (m) => m[1]!.toUpperCase());

String toSnake(String s) => s.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

/// Ligne snake_case → document camelCase. Les valeurs nulles sont omises
/// (Firestore n'avait pas de champ plutôt qu'un champ vide) et le jsonb `legacy` est fusionné.
Json rowToDoc(Json row) {
  final out = <String, dynamic>{};
  final legacy = row['legacy'];
  if (legacy is Map) {
    legacy.forEach((k, v) {
      if (v != null) out['$k'] = v;
    });
  }
  row.forEach((k, v) {
    if (k == 'legacy' || k == 'geo' || v == null) return;
    out[toCamel(k)] = v;
  });
  return out;
}

/// Course : coordonnées imbriquées `pickup` / `destination` comme dans l'ancien document.
Json rideRowToDoc(Json row) {
  final d = rowToDoc(row);
  d['pickup'] = {'lat': row['pickup_lat'], 'lng': row['pickup_lng']};
  d['destination'] = {'lat': row['destination_lat'], 'lng': row['destination_lng']};
  for (final k in const ['pickupLat', 'pickupLng', 'destinationLat', 'destinationLng']) {
    d.remove(k);
  }
  return d;
}

/// Message de course : l'horodatage s'appelait `timestamp`.
Json messageRowToDoc(Json row) {
  final d = rowToDoc(row);
  d['timestamp'] = row['created_at'];
  return d;
}

/// Document camelCase → colonnes. Seules les clés de [columns] (camelCase) sont écrites ;
/// une valeur `null` efface la colonne. Les clés inconnues sont ignorées volontairement
/// (champs Firestore sans équivalent, ex. `lastTokenUpdate`).
Json docToRow(Json data, Set<String> columns) {
  final out = <String, dynamic>{};
  data.forEach((k, v) {
    if (columns.contains(k)) out[toSnake(k)] = v;
  });
  return out;
}

String nowIso() => DateTime.now().toUtc().toIso8601String();
