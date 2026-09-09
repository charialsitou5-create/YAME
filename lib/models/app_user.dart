import 'app_mode.dart';
import 'vehicle_type.dart';

/// Modèle utilisateur, mappé sur le document Firestore `users/{uid}`.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    this.email,
    this.createdAt,
    this.activeMode = AppMode.client,
    this.driverVehicleType,
    this.vehicleRegistered = false,
    this.clientActiveRideId,
    this.driverActiveRideId,
  });

  final String uid;
  final String name;
  final String phone;
  final String? email;
  final DateTime? createdAt;

  /// Mode actuellement affiché par `HomeScreen`.
  final AppMode activeMode;

  /// Type de véhicule chauffeur (voiture/moto), posé une fois au moment où
  /// l'utilisateur choisit de devenir chauffeur — ne change plus ensuite,
  /// même si `activeMode` repasse à `client`. `null` tant qu'il n'a jamais
  /// démarré l'inscription chauffeur.
  final VehicleType? driverVehicleType;

  /// Pour un compte ayant démarré l'inscription chauffeur : `true` une fois
  /// le véhicule/la moto enregistré (assistant d'inscription en 3 étapes
  /// complété).
  final bool vehicleRegistered;

  /// Id de la `ride_requests` en cours côté client (statut `searching` ou
  /// `accepted`), sinon `null`. Bloque le passage à `activeMode: driver`.
  final String? clientActiveRideId;

  /// Id de la `ride_requests` acceptée en cours côté chauffeur, sinon
  /// `null`. Bloque le passage à `activeMode: client`.
  final String? driverActiveRideId;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final vehicleTypeValue = map['driverVehicleType'] as String?;
    return AppUser(
      uid: uid,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
      activeMode: AppMode.fromFirestoreValue(map['activeMode'] as String? ?? ''),
      driverVehicleType: vehicleTypeValue == null
          ? null
          : VehicleType.values.asNameMap()[vehicleTypeValue],
      vehicleRegistered: map['vehicleRegistered'] as bool? ?? false,
      clientActiveRideId: map['clientActiveRideId'] as String?,
      driverActiveRideId: map['driverActiveRideId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      if (email != null && email!.isNotEmpty) 'email': email,
      'activeMode': activeMode.firestoreValue,
      if (driverVehicleType != null) 'driverVehicleType': driverVehicleType!.name,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'vehicleRegistered': vehicleRegistered,
    };
  }

  AppUser copyWith({
    String? name,
    String? phone,
    String? email,
    AppMode? activeMode,
    VehicleType? driverVehicleType,
    bool? vehicleRegistered,
    String? clientActiveRideId,
    String? driverActiveRideId,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt,
      activeMode: activeMode ?? this.activeMode,
      driverVehicleType: driverVehicleType ?? this.driverVehicleType,
      vehicleRegistered: vehicleRegistered ?? this.vehicleRegistered,
      clientActiveRideId: clientActiveRideId ?? this.clientActiveRideId,
      driverActiveRideId: driverActiveRideId ?? this.driverActiveRideId,
    );
  }
}
