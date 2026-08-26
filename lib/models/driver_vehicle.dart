import 'vehicle_type.dart';

/// Véhicule (voiture ou moto) déclaré par un chauffeur, mappé sur le
/// document Firestore `driver_profiles/{uid}`.
class DriverVehicle {
  const DriverVehicle({
    required this.vehicleType,
    required this.model,
    required this.year,
    required this.plate,
    required this.seats,
    this.color,
  });

  final VehicleType vehicleType;
  final String model;
  final int year;
  final String plate;
  final int seats;

  /// Renseignée pour une voiture uniquement (la moto n'a pas ce champ
  /// dans la maquette).
  final String? color;

  Map<String, dynamic> toMap() {
    return {
      'vehicleType': vehicleType.name,
      'model': model,
      'year': year,
      'plate': plate,
      'seats': seats,
      if (color != null && color!.isNotEmpty) 'color': color,
      'balance': 0,
      'status': 'pending_verification',
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}
