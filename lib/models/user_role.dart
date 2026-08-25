import '../core/constants/app_strings.dart';

/// Les trois profils possibles sur Yame.
enum UserRole {
  client,
  chauffeurVoiture,
  chauffeurMoto;

  /// Valeur stockée dans Firestore (`users/{uid}.role`).
  String get firestoreValue => switch (this) {
        UserRole.client => 'client',
        UserRole.chauffeurVoiture => 'chauffeur_voiture',
        UserRole.chauffeurMoto => 'chauffeur_moto',
      };

  String get label => switch (this) {
        UserRole.client => AppStrings.roleClient,
        UserRole.chauffeurVoiture => AppStrings.roleDriverCar,
        UserRole.chauffeurMoto => AppStrings.roleDriverMoto,
      };

  String get description => switch (this) {
        UserRole.client => AppStrings.roleClientDescription,
        UserRole.chauffeurVoiture => AppStrings.roleDriverCarDescription,
        UserRole.chauffeurMoto => AppStrings.roleDriverMotoDescription,
      };

  bool get isDriver => this != UserRole.client;

  static UserRole fromFirestoreValue(String value) {
    return UserRole.values.firstWhere(
      (role) => role.firestoreValue == value,
      orElse: () => UserRole.client,
    );
  }
}
