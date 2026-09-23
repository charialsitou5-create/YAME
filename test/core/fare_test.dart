import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:yame/core/fare.dart';
import 'package:yame/models/vehicle_type.dart';

void main() {
  const a = LatLng(-4.7889, 11.8656);
  const b = LatLng(-4.8300, 11.8656); // ~4,57 km au sud

  test('sans config, la grille par défaut reproduit les anciens tarifs', () {
    final car = estimateFareFcfa(pickup: a, destination: b, vehicleType: VehicleType.car);
    final moto = estimateFareFcfa(pickup: a, destination: b, vehicleType: VehicleType.moto);
    expect(car, 3300); // 1000 + 500 * 4.57 = 3285 -> 3300
    expect(moto, 1900); // 500 + 300 * 4.57 = 1871 -> 1900
  });

  test('une grille personnalisée est appliquée par type de véhicule', () {
    const pricing = FarePricing(
      car: VehicleFare(base: 2000, perKm: 600),
      moto: VehicleFare(base: 500, perKm: 300),
    );
    expect(estimateFareFcfa(pickup: a, destination: b, vehicleType: VehicleType.car, pricing: pricing), 4700);
    expect(estimateFareFcfa(pickup: a, destination: b, vehicleType: VehicleType.moto, pricing: pricing), 1900);
  });

  test('FarePricing.fromMap ignore les valeurs invalides et garde le secours', () {
    final p = FarePricing.fromMap({
      'car': {'base': 1500, 'perKm': -5},
      'moto': 'n/a',
    });
    expect(p.car.base, 1500);
    expect(p.car.perKm, 500);
    expect(p.moto.base, 500);
    expect(FarePricing.fromMap(null).car.base, 1000);
  });
}
