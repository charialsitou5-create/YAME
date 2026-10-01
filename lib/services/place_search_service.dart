import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceResult {
  const PlaceResult({required this.label, required this.point});

  final String label;
  final LatLng point;
}

/// Recherche d'adresses/lieux par texte via Nominatim (OpenStreetMap), gratuit
/// et cohérent avec la carte OSM — zéro clé ni carte bancaire. Les résultats
/// sont biaisés vers [near] (la zone visible/la position de l'utilisateur)
/// sans exclure le reste du monde. Retourne une liste vide en cas d'échec.
class PlaceSearchService {
  PlaceSearchService._();

  static Future<List<PlaceResult>> search(
    String query, {
    LatLng? near,
    http.Client? client,
  }) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final params = <String, String>{
      'q': q,
      'format': 'jsonv2',
      'limit': '8',
      'addressdetails': '0',
      'accept-language': 'fr',
      if (near != null)
        'viewbox':
            '${near.longitude - 0.5},${near.latitude + 0.5},${near.longitude + 0.5},${near.latitude - 0.5}',
    };
    try {
      final c = client ?? http.Client();
      final response = await c
          .get(
            Uri.https('nominatim.openstreetmap.org', '/search', params),
            headers: {'User-Agent': 'com.yame.yame'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const [];
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return PlaceResult(
          label: m['display_name'] as String? ?? '',
          point: LatLng(
            double.parse(m['lat'] as String),
            double.parse(m['lon'] as String),
          ),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }
}
