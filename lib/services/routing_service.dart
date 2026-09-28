import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Itinéraire réel entre deux points (tracé + distance + durée), calculé
/// par un serveur de routing plutôt qu'à vol d'oiseau (voir `core/fare.dart`
/// pour l'estimation à vol d'oiseau utilisée pour le prix).
class RouteResult {
  const RouteResult({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> polyline;
  final double distanceMeters;
  final double durationSeconds;

  Duration get duration => Duration(seconds: durationSeconds.round());
}

/// Formatte une durée en "X min" (ou "XhYY" au-delà d'une heure, rare pour
/// un trajet urbain mais évite un affichage à trois chiffres de minutes).
String formatEta(Duration eta) {
  final totalMinutes = (eta.inSeconds / 60).round().clamp(1, 999);
  if (totalMinutes < 60) return '$totalMinutes min';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return '${hours}h${minutes.toString().padLeft(2, '0')}';
}

/// Calcule un itinéraire routier via le serveur de démonstration public
/// OSRM (`router.project-osrm.org`, gratuit, cohérent avec le choix
/// OpenStreetMap déjà fait pour la carte — zéro clé/carte payante). Ce
/// serveur public n'offre aucune garantie de disponibilité ni de débit : en
/// cas d'échec ou de dépassement de délai, retourne `null` plutôt que de
/// lever une exception — l'appelant doit alors se rabattre sur l'affichage
/// existant (marqueurs seuls, sans tracé).
class RoutingService {
  RoutingService._();

  static const _baseUrl = 'https://router.project-osrm.org/route/v1/driving';

  static Future<RouteResult?> fetchRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') return null;

      final routes = body['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;

      final coordinates = (route['geometry'] as Map<String, dynamic>)['coordinates'] as List<dynamic>;
      final polyline = coordinates.map((c) {
        final pair = c as List<dynamic>;
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList();

      return RouteResult(
        polyline: polyline,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
