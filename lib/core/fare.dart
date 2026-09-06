import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../models/vehicle_type.dart';

/// Estimation du prix d'une course à partir de la distance à vol d'oiseau
/// entre le départ et la destination (aucun suivi GPS en temps réel n'étant
/// disponible pendant la course).
int estimateFareFcfa({
  required LatLng pickup,
  required LatLng destination,
  required VehicleType vehicleType,
}) {
  final distanceKm = _haversineKm(pickup, destination);
  final baseFare = vehicleType == VehicleType.car ? 1000 : 500;
  final perKm = vehicleType == VehicleType.car ? 500 : 300;
  final raw = baseFare + perKm * distanceKm;
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

