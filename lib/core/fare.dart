import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../models/vehicle_type.dart';

/// Tarif d'un type de véhicule : prise en charge + prix au kilomètre (FCFA).
class VehicleFare {
  const VehicleFare({required this.base, required this.perKm});

  final int base;
  final int perKm;

  /// Lit `{base, perKm}` ; toute valeur absente, non numérique ou négative
  /// retombe sur [fallback] pour qu'une config mal saisie ne casse pas le prix.
  factory VehicleFare.fromMap(Object? data, VehicleFare fallback) {
    if (data is! Map) return fallback;
    int read(Object? v, int def) => v is num && v >= 0 ? v.round() : def;
    return VehicleFare(base: read(data['base'], fallback.base), perKm: read(data['perKm'], fallback.perKm));
  }
}

/// Grille tarifaire, réglée depuis l'admin (document `app_config/pricing`).
class FarePricing {
  const FarePricing({required this.car, required this.moto});

  final VehicleFare car;
  final VehicleFare moto;

  /// Valeurs en vigueur avant l'introduction de la config : servent de secours
  /// si le document est absent ou illisible (hors ligne, erreur réseau).
  static const defaults = FarePricing(
    car: VehicleFare(base: 1000, perKm: 500),
    moto: VehicleFare(base: 500, perKm: 300),
  );

  factory FarePricing.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    return FarePricing(
      car: VehicleFare.fromMap(data['car'], defaults.car),
      moto: VehicleFare.fromMap(data['moto'], defaults.moto),
    );
  }

  VehicleFare forVehicle(VehicleType type) => type == VehicleType.car ? car : moto;
}

/// Charge la grille depuis Firestore ; n'échoue jamais (secours : [FarePricing.defaults]).
Future<FarePricing> loadFarePricing() async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('pricing')
        .get()
        .timeout(const Duration(seconds: 5));
    return FarePricing.fromMap(snap.data());
  } catch (_) {
    return FarePricing.defaults;
  }
}

/// Estimation du prix d'une course à partir de la distance à vol d'oiseau
/// entre le départ et la destination (aucun suivi GPS en temps réel n'étant
/// disponible pendant la course).
int estimateFareFcfa({
  required LatLng pickup,
  required LatLng destination,
  required VehicleType vehicleType,
  FarePricing pricing = FarePricing.defaults,
}) {
  final distanceKm = _haversineKm(pickup, destination);
  final fare = pricing.forVehicle(vehicleType);
  final raw = fare.base + fare.perKm * distanceKm;
  return (raw / 100).round() * 100;
}

double _haversineKm(LatLng a, LatLng b) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(b.latitude - a.latitude);
  final dLng = _degToRad(b.longitude - a.longitude);
  final lat1 = _degToRad(a.latitude);
  final lat2 = _degToRad(b.latitude);

  final h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(h), sqrt(1 - h));
  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * pi / 180;

/// Formate un montant FCFA avec un espace tous les 3 chiffres (ex: 5 000).
String formatFcfa(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

