/// Le mode actuellement affiché par `HomeScreen` pour ce compte —
/// basculable depuis `ProfilScreen` une fois `driverVehicleType` approuvé.
enum AppMode {
  client,
  driver;

  /// Valeur stockée dans Firestore (`users/{uid}.activeMode`).
  String get firestoreValue => switch (this) {
        AppMode.client => 'client',
        AppMode.driver => 'driver',
      };

  static AppMode fromFirestoreValue(String value) {
    return AppMode.values.firstWhere(
      (mode) => mode.firestoreValue == value,
      orElse: () => AppMode.client,
    );
  }
}
