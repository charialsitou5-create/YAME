import 'user_role.dart';

/// Modèle utilisateur, mappé sur le document Firestore `users/{uid}`.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    required this.role,
    this.email,
    this.createdAt,
    this.vehicleRegistered = false,
  });

  final String uid;
  final String name;
  final String phone;
  final String? email;
  final UserRole role;
  final DateTime? createdAt;

  /// Pour un profil chauffeur : `true` une fois le véhicule/la moto
  /// enregistré (assistant d'inscription en 3 étapes complété).
  final bool vehicleRegistered;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String?,
      role: UserRole.fromFirestoreValue(map['role'] as String? ?? ''),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
      vehicleRegistered: map['vehicleRegistered'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      if (email != null && email!.isNotEmpty) 'email': email,
      'role': role.firestoreValue,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'vehicleRegistered': vehicleRegistered,
    };
  }

  AppUser copyWith({
    String? name,
    String? phone,
    String? email,
    UserRole? role,
    bool? vehicleRegistered,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt,
      vehicleRegistered: vehicleRegistered ?? this.vehicleRegistered,
    );
  }
}
