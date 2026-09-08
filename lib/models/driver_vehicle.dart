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
    this.photoUrls = const {},
    this.registrationCardUrl,
    this.licenseUrl,
  });

  final VehicleType vehicleType;
  final String model;
  final int year;
  final String plate;
  final int seats;

  /// Renseignée pour une voiture uniquement (la moto n'a pas ce champ
  /// dans la maquette).
  final String? color;

  /// Photos du véhicule (face avant, arrière, côtés, vue d'ensemble),
  /// indexées par leur libellé — utilisées par l'admin pour la validation.
  final Map<String, String> photoUrls;

  /// Documents requis pour la validation par l'admin.
  final String? registrationCardUrl;
  final String? licenseUrl;

  Map<String, dynamic> toMap() {
    return {
      'vehicleType': vehicleType.name,
      'model': model,
      'year': year,
      'plate': plate,
      'seats': seats,
      if (color != null && color!.isNotEmpty) 'color': color,
      if (photoUrls.isNotEmpty) 'photoUrls': photoUrls,
      if (registrationCardUrl != null)
        'registrationCardUrl': registrationCardUrl,
      if (licenseUrl != null) 'licenseUrl': licenseUrl,
      'status': 'pending_verification',
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}
