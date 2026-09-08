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

  /// Champs publics du véhicule (visibles par tout utilisateur connecté une
  /// fois le chauffeur approuvé) — sans les documents d'identité, qui vont
  /// dans une sous-collection privée séparée, voir [toDocumentsMap].
  Map<String, dynamic> toMap() {
    return {
      'vehicleType': vehicleType.name,
      'model': model,
      'year': year,
      'plate': plate,
      'seats': seats,
      if (color != null && color!.isNotEmpty) 'color': color,
      'status': 'pending_verification',
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  /// Documents d'identité (carte grise, permis, photos du véhicule) — écrits
  /// dans `driver_profiles/{uid}/documents/current`, lisible uniquement par
  /// le chauffeur propriétaire et l'admin (Admin SDK), jamais par tout
  /// utilisateur connecté comme le reste de la fiche.
  Map<String, dynamic> toDocumentsMap() {
    return {
      if (photoUrls.isNotEmpty) 'photoUrls': photoUrls,
      if (registrationCardUrl != null)
        'registrationCardUrl': registrationCardUrl,
      if (licenseUrl != null) 'licenseUrl': licenseUrl,
    };
  }
}
