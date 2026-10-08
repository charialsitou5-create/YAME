import 'package:latlong2/latlong.dart';

/// Configuration d'environnement de l'app.
class AppConfig {
  AppConfig._();

  // URL de production du panneau admin (yame-admin, déployé sur Vercel) — c'est
  // ce service qui expose /api/rides/dispatch, /api/rides/respond et
  // /api/recharge/initiate (contacte MTN/Airtel pour le compte du chauffeur).
  /// Ville de lancement et centre de carte par défaut (utilisé tant que la
  /// position de l'utilisateur est inconnue). Valeurs actuelles : Pointe-Noire.
  static const defaultCityName = 'Pointe-Noire';
  static const defaultMapCenter = LatLng(-4.7889, 11.8656);

  static const adminApiBaseUrl = 'https://yame-admin.vercel.app';
}
