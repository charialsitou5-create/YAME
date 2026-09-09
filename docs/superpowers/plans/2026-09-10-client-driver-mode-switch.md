# Switch client / chauffeur Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an approved driver toggle between client and driver mode from `ProfilScreen`, blocked while a ride is active, without losing the existing "driver must be admin-approved before working" guarantee.

**Architecture:** Replace the fixed `users/{uid}.role` (`UserRole`) with `activeMode` (`AppMode.client`/`AppMode.driver`, switchable) and `driverVehicleType` (fixed once, set the moment a vehicle type is chosen). Two more fields, `clientActiveRideId`/`driverActiveRideId`, track whether each side has a live ride, updated by the account's own writes at each ride transition (batched with the `ride_requests` write where the acting account can do both in one commit; reactively by the client's own listener when the driver is the one who ends the ride, since `users/{uid}` can only be written by its owner).

**Tech Stack:** Flutter/Dart, Cloud Firestore, Firebase Auth. No mocking framework in this project — `AppUser`/`AppMode` are pure Dart and get real `flutter_test` unit tests; everything touching Firestore is verified by `flutter analyze` plus manual testing on the Android emulator (`Yame_Pixel`), matching this project's existing convention (see spec's Test section).

**Spec:** `docs/superpowers/specs/2026-09-10-client-driver-mode-switch-design.md`

## Global Constraints

- `users/{userId}` stays writable only by its owner (`request.auth.uid == userId`) — no task may add a write from one account to another account's `users` document.
- Chauffeur → client switch never requires new admin validation; client → chauffeur still requires `driver_profiles/{uid}.status == 'approved'`.
- Switch is blocked while `clientActiveRideId` (client leaving `client` mode) or `driverActiveRideId` (driver leaving `driver` mode) is non-null on the account's own `users/{uid}` doc.
- No migration script — the 2 known Firebase Auth test accounts are deleted and recreated after this ships (Task 9).

---

### Task 1: `AppMode` + `AppUser` data model

**Files:**
- Create: `lib/models/app_mode.dart`
- Modify: `lib/models/app_user.dart`
- Test: `test/models/app_user_test.dart`

**Interfaces:**
- Produces: `AppMode` enum (`client`, `driver`) with `firestoreValue` getter and `AppMode.fromFirestoreValue(String)` static method. `AppUser` fields: `activeMode` (`AppMode`, default `AppMode.client`), `driverVehicleType` (`VehicleType?`), `clientActiveRideId` (`String?`), `driverActiveRideId` (`String?`) — replacing the removed `role` field. `AppUser.fromMap`/`toMap`/`copyWith` updated accordingly.

- [ ] **Step 1: Create `AppMode`**

```dart
// lib/models/app_mode.dart

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
```

- [ ] **Step 2: Write the failing test**

```dart
// test/models/app_user_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yame/models/app_mode.dart';
import 'package:yame/models/app_user.dart';
import 'package:yame/models/vehicle_type.dart';

void main() {
  group('AppUser', () {
    test('fromMap defaults activeMode to client and driver fields to null when absent', () {
      final user = AppUser.fromMap('uid1', {'name': 'Test', 'phone': '060000000'});

      expect(user.activeMode, AppMode.client);
      expect(user.driverVehicleType, isNull);
      expect(user.clientActiveRideId, isNull);
      expect(user.driverActiveRideId, isNull);
    });

    test('toMap/fromMap round-trips activeMode and driverVehicleType for a driver account', () {
      const user = AppUser(
        uid: 'uid2',
        name: 'Chauffeur Test',
        phone: '061111111',
        activeMode: AppMode.driver,
        driverVehicleType: VehicleType.moto,
        vehicleRegistered: true,
      );

      final roundTripped = AppUser.fromMap('uid2', user.toMap());

      expect(roundTripped.activeMode, AppMode.driver);
      expect(roundTripped.driverVehicleType, VehicleType.moto);
      expect(roundTripped.vehicleRegistered, isTrue);
    });

    test('clientActiveRideId and driverActiveRideId are read straight from Firestore fields', () {
      final user = AppUser.fromMap('uid3', {
        'name': 'Client Test',
        'phone': '062222222',
        'clientActiveRideId': 'ride123',
      });

      expect(user.clientActiveRideId, 'ride123');
      expect(user.driverActiveRideId, isNull);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails (compile error — `AppUser` doesn't have these fields yet)**

Run: `flutter test test/models/app_user_test.dart`
Expected: FAIL (compile error referencing `activeMode`/`driverVehicleType`/`AppMode`)

- [ ] **Step 4: Rewrite `AppUser`**

```dart
// lib/models/app_user.dart
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
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/models/app_user_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add lib/models/app_mode.dart lib/models/app_user.dart test/models/app_user_test.dart
git commit -m "feat: add AppMode and switch AppUser from role to activeMode/driverVehicleType"
```

*(`lib/models/user_role.dart` is NOT deleted yet — other files still import it until Tasks 3-5 land. Deleted in Task 8.)*

---

### Task 2: Firestore rule — guard `activeMode` changes

**Files:**
- Modify: `firestore.rules`

**Interfaces:**
- Consumes: `users/{userId}.activeMode`, `.clientActiveRideId`, `.driverActiveRideId` (written by Task 1's model via Tasks 3, 6, 7).

- [ ] **Step 1: Replace the `users/{userId}` match block**

```
    // Chaque utilisateur ne peut lire/écrire que son propre profil. Un
    // changement de `activeMode` (bascule client/chauffeur, voir
    // ProfilScreen) est en plus soumis à ce qu'aucune course ne soit active
    // dans le mode qu'on quitte — clientActiveRideId/driverActiveRideId sont
    // tenus à jour par l'app aux points de transition d'une course (voir
    // booking_screen.dart / driver_home_screen.dart). Ça bloque les bascules
    // accidentelles/bugs UI, pas un client qui bricolerait ces deux champs à
    // la main via une requête Firestore brute — un blindage complet
    // demanderait une Cloud Function, hors scope ici (cohérent avec le
    // reste de ce fichier, qui fait déjà confiance à des invariants basés
    // sur `diff().affectedKeys()` plutôt que sur des Cloud Functions).
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null && request.auth.uid == userId;
      allow update: if request.auth != null && request.auth.uid == userId && (
        request.resource.data.get('activeMode', null) == resource.data.get('activeMode', null)
        || (resource.data.get('activeMode', null) == 'client'
            ? resource.data.get('clientActiveRideId', null) == null
            : resource.data.get('driverActiveRideId', null) == null)
      );
      allow delete: if false;
    }
```

- [ ] **Step 2: Deploy the rules**

Run: `cd /Users/dieselngoma/Documents/ANTIGRAVITY/Yame/YAME && firebase deploy --only firestore:rules`
Expected: `✔ Deploy complete!`

- [ ] **Step 3: Commit**

```bash
git add firestore.rules
git commit -m "feat: guard activeMode switch behind no-active-ride check in Firestore rules"
```

---

### Task 3: Onboarding/signup entry point — `VehicleType?` instead of `UserRole`

**Files:**
- Modify: `lib/routes/app_routes.dart`
- Modify: `lib/features/onboarding/onboarding_screen.dart`
- Modify: `lib/features/auth/signup_screen.dart`

**Interfaces:**
- Consumes: `AppMode`, `AppUser` from Task 1.
- Produces: `AppRoutes.signup` now expects a `VehicleType?` route argument (`null` = client signup).

- [ ] **Step 1: `app_routes.dart` — route argument type**

```dart
// lib/routes/app_routes.dart
import 'package:flutter/material.dart';

import '../features/auth/auth_gate.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/home/home_screen.dart';
import '../models/vehicle_type.dart';

/// Table de routage nommée de l'application.
class AppRoutes {
  AppRoutes._();

  static const onboarding = '/';
  static const signup = '/signup';
  static const login = '/login';
  static const home = '/home';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case onboarding:
        return MaterialPageRoute(builder: (_) => const AuthGate());
      case signup:
        final vehicleType = settings.arguments as VehicleType?;
        return MaterialPageRoute(builder: (_) => SignupScreen(vehicleType: vehicleType));
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      default:
        return MaterialPageRoute(builder: (_) => const AuthGate());
    }
  }
}
```

- [ ] **Step 2: `onboarding_screen.dart` — `_RoleCard` takes label/description directly**

Replace the three `_RoleCard(...)` usages:

```dart
                  _RoleCard(
                    label: AppStrings.roleClient,
                    description: AppStrings.roleClientDescription,
                    icon: Icons.person_rounded,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.signup, arguments: null),
                  ),
                  const SizedBox(height: 14),
                  _RoleCard(
                    label: AppStrings.roleDriverCar,
                    description: AppStrings.roleDriverCarDescription,
                    icon: Icons.directions_car_filled_rounded,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.signup, arguments: VehicleType.car),
                  ),
                  const SizedBox(height: 14),
                  _RoleCard(
                    label: AppStrings.roleDriverMoto,
                    description: AppStrings.roleDriverMotoDescription,
                    icon: Icons.two_wheeler_rounded,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.signup, arguments: VehicleType.moto),
                  ),
```

Replace the `_RoleCard` class itself:

```dart
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.textPrimary,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.background),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.lightTextPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
```

Replace the import `import '../../models/user_role.dart';` with `import '../../models/vehicle_type.dart';`.

- [ ] **Step 3: `signup_screen.dart` — take `VehicleType?`, write `activeMode`/`driverVehicleType`**

Replace the imports block:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/app_mode.dart';
import '../../models/app_user.dart';
import '../../models/vehicle_type.dart';
import '../../routes/app_routes.dart';
```

Replace the constructor:

```dart
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.vehicleType});

  final VehicleType? vehicleType;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}
```

Replace the `AppUser` construction inside `_submit()`:

```dart
      final uid = credential.user!.uid;
      final user = AppUser(
        uid: uid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        activeMode: widget.vehicleType == null ? AppMode.client : AppMode.driver,
        driverVehicleType: widget.vehicleType,
      );
      await FirebaseFirestore.instance.collection('users').doc(uid).set(user.toMap());
```

- [ ] **Step 4: Verify with `flutter analyze` (expect remaining errors only in files not yet touched — Tasks 4/5)**

Run: `flutter analyze lib/routes/app_routes.dart lib/features/onboarding/onboarding_screen.dart lib/features/auth/signup_screen.dart`
Expected: No issues found in these 3 files.

- [ ] **Step 5: Commit**

```bash
git add lib/routes/app_routes.dart lib/features/onboarding/onboarding_screen.dart lib/features/auth/signup_screen.dart
git commit -m "feat: onboarding/signup pick a VehicleType? instead of a UserRole"
```

---

### Task 4: Driver-flow screens take `VehicleType` instead of `UserRole`

**Files:**
- Modify: `lib/features/driver/driver_intro_screen.dart`
- Modify: `lib/features/driver/vehicle_registration_wizard.dart`
- Modify: `lib/features/driver/driver_home_screen.dart`

**Interfaces:**
- Consumes: `VehicleType` (existing, `lib/models/vehicle_type.dart`).
- Produces: `DriverIntroScreen({required VehicleType vehicleType})`, `VehicleRegistrationWizard({required VehicleType vehicleType})`, `DriverHomeScreen({required VehicleType vehicleType, required String driverName})` — pure rename, no behavior change in this task.

- [ ] **Step 1: `driver_intro_screen.dart`**

Replace the import `import '../../models/user_role.dart';` with `import '../../models/vehicle_type.dart';`.

Replace the constructor:

```dart
class DriverIntroScreen extends StatelessWidget {
  const DriverIntroScreen({super.key, required this.vehicleType});

  final VehicleType vehicleType;
```

Replace the label `TextSpan`:

```dart
                        TextSpan(
                          text: vehicleType == VehicleType.car
                              ? AppStrings.roleDriverCar
                              : AppStrings.roleDriverMoto,
                          style: const TextStyle(color: AppColors.accentBright),
                        ),
```

Replace the CTA button's `onPressed`:

```dart
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VehicleRegistrationWizard(vehicleType: vehicleType),
                        ),
                      ),
```

- [ ] **Step 2: `vehicle_registration_wizard.dart`**

Remove `import '../../models/user_role.dart';` (the file already imports `vehicle_type.dart`).

Replace the constructor:

```dart
class VehicleRegistrationWizard extends StatefulWidget {
  const VehicleRegistrationWizard({super.key, required this.vehicleType});

  final VehicleType vehicleType;
```

Replace the two remaining usages of `widget.role`:

```dart
  late final bool _isCar = widget.vehicleType == VehicleType.car;
```

```dart
      final vehicle = DriverVehicle(
        vehicleType: widget.vehicleType,
```

- [ ] **Step 3: `driver_home_screen.dart`**

Remove `import '../../models/user_role.dart';` (the file already imports `vehicle_type.dart`).

Replace the constructor:

```dart
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({
    super.key,
    required this.vehicleType,
    required this.driverName,
  });

  final VehicleType vehicleType;
  final String driverName;
```

Replace the getter:

```dart
  VehicleType get _vehicleType => widget.vehicleType;
```

- [ ] **Step 4: Verify with `flutter analyze`**

Run: `flutter analyze lib/features/driver/driver_intro_screen.dart lib/features/driver/vehicle_registration_wizard.dart lib/features/driver/driver_home_screen.dart`
Expected: No issues found in these 3 files (their own callers — `HomeScreen` — are fixed in Task 5, so cross-file errors from the old call sites are expected to persist until then).

- [ ] **Step 5: Commit**

```bash
git add lib/features/driver/driver_intro_screen.dart lib/features/driver/vehicle_registration_wizard.dart lib/features/driver/driver_home_screen.dart
git commit -m "refactor: driver-flow screens take VehicleType instead of UserRole"
```

---

### Task 5: `HomeScreen` routes on `activeMode` / `driverVehicleType`

**Files:**
- Modify: `lib/features/home/home_screen.dart`

**Interfaces:**
- Consumes: `AppUser.activeMode`, `.driverVehicleType`, `.vehicleRegistered` (Task 1); `DriverIntroScreen`/`DriverHomeScreen` new `vehicleType` param (Task 4).

- [ ] **Step 1: Rewrite `HomeScreen`**

```dart
// lib/features/home/home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_mode.dart';
import '../../models/app_user.dart';
import '../driver/driver_home_screen.dart';
import '../driver/driver_intro_screen.dart';
import '../driver/driver_status_screen.dart';
import 'client_shell.dart';

/// Aiguille vers l'écran de réservation (client) ou l'écran chauffeur,
/// selon `activeMode` du profil chargé depuis Firestore.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        if (data == null) return const SizedBox.shrink();

        final user = AppUser.fromMap(uid, data);
        if (user.activeMode == AppMode.client) {
          return ClientShell(name: user.name);
        }

        final vehicleType = user.driverVehicleType;
        if (vehicleType == null) {
          // Filet de sécurité : activeMode ne devrait jamais être `driver`
          // sans qu'un véhicule ait été choisi (voir signup_screen.dart /
          // ProfilScreen).
          return ClientShell(name: user.name);
        }
        if (!user.vehicleRegistered) {
          return DriverIntroScreen(vehicleType: vehicleType);
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('driver_profiles')
              .doc(uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            final status =
                profileSnapshot.data?.data()?['status'] as String? ??
                'pending_verification';
            if (status == 'rejected') {
              return const DriverStatusScreen(rejected: true);
            }
            if (status != 'approved') {
              return const DriverStatusScreen(rejected: false);
            }
            return DriverHomeScreen(vehicleType: vehicleType, driverName: user.name);
          },
        );
      },
    );
  }
}
```

- [ ] **Step 2: Verify with `flutter analyze`**

Run: `flutter analyze lib/features/home/home_screen.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/home_screen.dart
git commit -m "refactor: HomeScreen routes on activeMode/driverVehicleType instead of UserRole"
```

---

### Task 6: Active-ride bookkeeping (`clientActiveRideId` / `driverActiveRideId`)

**Files:**
- Modify: `lib/features/booking/booking_screen.dart`
- Modify: `lib/features/driver/driver_home_screen.dart`

**Interfaces:**
- Consumes: `users/{uid}.clientActiveRideId` / `.driverActiveRideId` (Task 1/2).
- Produces: both fields kept correctly in sync (set on create/accept, cleared on cancel/complete) including after an app restart mid-ride (see spec's "piège existant").

- [ ] **Step 1: `booking_screen.dart` — recover `_activeRequestId` on startup**

Add a field and call it from `initState`:

```dart
  String? _activeRequestId;
  bool _submittingRequest = false;
  RideRecipient? _recipient;
  bool _clientActiveRideCleared = false;

  @override
  void initState() {
    super.initState();
    _locateMe();
    _recoverActiveRequest();
  }

  Future<void> _recoverActiveRequest() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final activeId = doc.data()?['clientActiveRideId'] as String?;
    if (activeId != null && mounted) {
      setState(() => _activeRequestId = activeId);
    }
  }
```

- [ ] **Step 2: `booking_screen.dart` — batch-write `clientActiveRideId` on request creation**

Replace `_requestDriver`:

```dart
  Future<void> _requestDriver() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _pickupPosition == null || _destinationPosition == null) return;

    setState(() => _submittingRequest = true);
    try {
      final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final clientName = profile.data()?['name'] as String? ?? '';

      final request = RideRequest(
        clientUid: user.uid,
        clientName: clientName,
        pickup: _pickupPosition!,
        pickupAddress: _pickupAddress,
        destination: _destinationPosition!,
        destinationAddress: _destinationAddress,
        vehicleType: _vehicleType,
        status: RideStatus.searching,
        recipientName: _recipient?.name,
        recipientPhone: _recipient?.phone,
        recipientInstructions: _recipient?.instructions,
        contactRequesterInstead: _recipient?.contactRequesterInstead ?? false,
      );

      final requestRef = FirebaseFirestore.instance.collection('ride_requests').doc();
      final batch = FirebaseFirestore.instance.batch()
        ..set(requestRef, request.toMap())
        ..update(FirebaseFirestore.instance.collection('users').doc(user.uid), {
          'clientActiveRideId': requestRef.id,
        });
      await batch.commit();

      if (!mounted) return;
      setState(() {
        _activeRequestId = requestRef.id;
        _clientActiveRideCleared = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.bookingRequestError)),
      );
    } finally {
      if (mounted) setState(() => _submittingRequest = false);
    }
  }
```

- [ ] **Step 3: `booking_screen.dart` — clear `clientActiveRideId` when the client cancels a still-`searching` request**

Replace `_cancelRequest`:

```dart
  Future<void> _cancelRequest() async {
    final id = _activeRequestId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (id == null || uid == null) return;
    final batch = FirebaseFirestore.instance.batch()
      ..update(FirebaseFirestore.instance.collection('ride_requests').doc(id), {
        'status': RideStatus.cancelled.firestoreValue,
      })
      ..update(FirebaseFirestore.instance.collection('users').doc(uid), {
        'clientActiveRideId': null,
      });
    await batch.commit();
    _clientActiveRideCleared = true;
  }
```

- [ ] **Step 4: `booking_screen.dart` — reactively clear `clientActiveRideId` once the driver ends the ride**

In `build()`, the `StreamBuilder` that renders `_RideStatusPanel` (the `else` branch of `_activeRequestId == null ? _BookingPanel(...) : StreamBuilder(...)`) — add the clear inside its `builder`:

```dart
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('ride_requests')
                        .doc(_activeRequestId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final doc = snapshot.data;
                      final ride = (doc != null && doc.exists) ? RideRequest.fromDoc(doc) : null;
                      if (ride != null &&
                          !_clientActiveRideCleared &&
                          (ride.status == RideStatus.completed ||
                              ride.status == RideStatus.cancelled)) {
                        _clientActiveRideCleared = true;
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .update({'clientActiveRideId': null});
                        }
                      }
                      return _RideStatusPanel(
                        status: ride?.status ?? RideStatus.searching,
                        ride: ride,
                        onCancel: _cancelRequest,
                        onNewBooking: _startNewBooking,
                      );
                    },
                  ),
```

Also reset the guard in `_startNewBooking`:

```dart
  void _startNewBooking() {
    setState(() {
      _activeRequestId = null;
      _recipient = null;
      _clientActiveRideCleared = false;
    });
  }
```

- [ ] **Step 5: `driver_home_screen.dart` — recover `_activeRideId` on startup**

Add an `initState` override (there wasn't one before — only `dispose` existed):

```dart
  @override
  void initState() {
    super.initState();
    _recoverActiveRide();
  }

  Future<void> _recoverActiveRide() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final activeId = doc.data()?['driverActiveRideId'] as String?;
    if (activeId != null && mounted) {
      setState(() => _activeRideId = activeId);
    }
  }
```

- [ ] **Step 6: `driver_home_screen.dart` — set `driverActiveRideId` inside the existing accept transaction**

Replace `_accept`:

```dart
  Future<void> _accept(RideRequest request) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final docRef = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(request.id);
    final locationRef = FirebaseFirestore.instance
        .collection('driver_profiles')
        .doc(uid)
        .collection('location')
        .doc('current');
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final currentStatus = snapshot.data()?['status'] as String?;
        if (currentStatus != RideStatus.searching.firestoreValue) {
          throw StateError('taken');
        }
        transaction.update(docRef, {
          'status': RideStatus.accepted.firestoreValue,
          'driverUid': uid,
          'driverName': widget.driverName,
        });
        // Autorise le client de cette course à lire la position GPS live
        // du chauffeur (firestore.rules : driver_profiles/location).
        transaction.set(
          locationRef,
          {'activeClientUid': request.clientUid},
          SetOptions(merge: true),
        );
        transaction.update(userRef, {'driverActiveRideId': request.id});
      });
      if (!mounted) return;
      setState(() => _activeRideId = request.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.driverRequestTaken)),
      );
    }
  }
```

- [ ] **Step 7: `driver_home_screen.dart` — clear `driverActiveRideId` when the ride ends**

Replace `_endRide`:

```dart
  Future<void> _endRide(RideStatus newStatus) async {
    final id = _activeRideId;
    if (id == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final batch = FirebaseFirestore.instance.batch()
      ..update(FirebaseFirestore.instance.collection('ride_requests').doc(id), {
        'status': newStatus.firestoreValue,
      });
    if (uid != null) {
      // Révoque l'accès du client à la position GPS live maintenant que
      // la course est terminée/annulée.
      batch.set(
        FirebaseFirestore.instance
            .collection('driver_profiles')
            .doc(uid)
            .collection('location')
            .doc('current'),
        {'activeClientUid': FieldValue.delete()},
        SetOptions(merge: true),
      );
      batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
        'driverActiveRideId': null,
      });
    }
    await batch.commit();
    if (!mounted) return;
    setState(() => _activeRideId = null);
  }
```

- [ ] **Step 8: Verify with `flutter analyze`**

Run: `flutter analyze lib/features/booking/booking_screen.dart lib/features/driver/driver_home_screen.dart`
Expected: No issues found.

- [ ] **Step 9: Commit**

```bash
git add lib/features/booking/booking_screen.dart lib/features/driver/driver_home_screen.dart
git commit -m "feat: keep clientActiveRideId/driverActiveRideId in sync, survive app restart mid-ride"
```

---

### Task 7: `ProfilScreen` — "Devenir chauffeur" + mode switch

**Files:**
- Modify: `lib/features/home/profil_screen.dart`
- Modify: `lib/core/constants/app_strings.dart`

**Interfaces:**
- Consumes: `AppUser.driverVehicleType`, `.activeMode`, `.clientActiveRideId`, `.driverActiveRideId` (Task 1); `VehicleRegistrationWizard({required VehicleType vehicleType})` (Task 4); `driver_profiles/{uid}.status` (existing).

- [ ] **Step 1: Add new strings**

In `lib/core/constants/app_strings.dart`, right after the existing `driverIntroCta` line (end of the "Inscription chauffeur — écran d'introduction" section):

```dart
  static const driverIntroCta = 'Suivant';

  // Profil — devenir chauffeur / bascule de mode
  static const profileBecomeDriverTitle = 'Devenez chauffeur';
  static const profileBecomeDriverSubtitle =
      'Gagnez de l\'argent avec Yame en plus de vos trajets.';
  static const profileBecomeDriverCta = 'Devenir chauffeur';
  static const profileBecomeDriverChooseVehicle = 'Choisissez votre véhicule';
  static const profileSwitchToDriver = 'Passer en mode chauffeur';
  static const profileSwitchToClient = 'Passer en mode client';
  static const profileSwitchBlocked =
      'Terminez votre course en cours avant de changer de mode.';
```

- [ ] **Step 2: Add imports to `profil_screen.dart`**

```dart
import '../../models/app_mode.dart';
import '../../models/app_user.dart';
import '../../models/vehicle_type.dart';
import '../../routes/app_routes.dart';
import '../driver/vehicle_registration_wizard.dart';
import '../support/report_issue_screen.dart';
```

(`app_user.dart` and `routes/app_routes.dart` and `report_issue_screen.dart` are already imported — only add the three new ones: `app_mode.dart`, `vehicle_type.dart`, `vehicle_registration_wizard.dart`.)

- [ ] **Step 3: Insert `_DriverSection` into the profile `ListView`**

Right after the "Activités" `Row` block and before the settings `Container`, insert:

```dart
              const SizedBox(height: 24),
              if (uid != null && user != null) ...[
                _DriverSection(uid: uid, user: user),
                const SizedBox(height: 16),
              ],
              Text(
                AppStrings.profileActivities,
```

(this places the new card between the profile header and the "Activités" title — adjust so it reads: profile card → driver section → activities title → activity stats → settings. The existing code order is: `_ProfileCard` → `SizedBox(24)` → `Text(profileActivities)` → activities `Row` → settings `Container`. Insert the new block right before the `Text(AppStrings.profileActivities, ...)` line, i.e. immediately after `_ProfileCard` and its `SizedBox(height: 24)`.)

- [ ] **Step 4: Add `_DriverSection` and `_VehicleTypeSheet` widgets**

Add at the end of `profil_screen.dart` (after the existing `_RowDivider` class):

```dart
class _DriverSection extends StatelessWidget {
  const _DriverSection({required this.uid, required this.user});

  final String uid;
  final AppUser user;

  Future<void> _pickVehicleType(BuildContext context) async {
    final type = await showModalBottomSheet<VehicleType>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _VehicleTypeSheet(),
    );
    if (type == null || !context.mounted) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'driverVehicleType': type.name,
    });
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VehicleRegistrationWizard(vehicleType: type)),
    );
  }

  Future<void> _switchMode(AppMode newMode) {
    return FirebaseFirestore.instance.collection('users').doc(uid).update({
      'activeMode': newMode.firestoreValue,
    });
  }

  @override
  Widget build(BuildContext context) {
    final vehicleType = user.driverVehicleType;

    if (vehicleType == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.profileBecomeDriverTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.profileBecomeDriverSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => _pickVehicleType(context),
              child: const Text(AppStrings.profileBecomeDriverCta),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('driver_profiles').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final status = snapshot.data?.data()?['status'] as String? ?? 'pending_verification';

        if (status != 'approved') {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              status == 'rejected'
                  ? AppStrings.driverRejectedTitle
                  : AppStrings.driverPendingTitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        final blocked = user.activeMode == AppMode.client
            ? user.clientActiveRideId != null
            : user.driverActiveRideId != null;
        final targetMode = user.activeMode == AppMode.client ? AppMode.driver : AppMode.client;
        final label = targetMode == AppMode.driver
            ? AppStrings.profileSwitchToDriver
            : AppStrings.profileSwitchToClient;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: blocked ? null : () => _switchMode(targetMode),
                child: Text(label),
              ),
              if (blocked) ...[
                const SizedBox(height: 8),
                Text(
                  AppStrings.profileSwitchBlocked,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _VehicleTypeSheet extends StatelessWidget {
  const _VehicleTypeSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.profileBecomeDriverChooseVehicle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.directions_car_filled_rounded, color: AppColors.accent),
              title: const Text(AppStrings.roleDriverCar),
              onTap: () => Navigator.of(context).pop(VehicleType.car),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.two_wheeler_rounded, color: AppColors.accent),
              title: const Text(AppStrings.roleDriverMoto),
              onTap: () => Navigator.of(context).pop(VehicleType.moto),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Verify with `flutter analyze`**

Run: `flutter analyze lib/features/home/profil_screen.dart lib/core/constants/app_strings.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/profil_screen.dart lib/core/constants/app_strings.dart
git commit -m "feat: ProfilScreen lets an approved driver switch client/driver mode"
```

---

### Task 8: Cleanup — remove `UserRole`

**Files:**
- Delete: `lib/models/user_role.dart`

**Interfaces:**
- Consumes: nothing (this task only runs once Tasks 3-5 have removed every `UserRole`/`user_role.dart` reference).

- [ ] **Step 1: Confirm nothing still references it**

Run: `grep -rn "UserRole\|user_role.dart" lib`
Expected: no output.

- [ ] **Step 2: Delete the file**

```bash
git rm lib/models/user_role.dart
```

- [ ] **Step 3: Full analyze pass**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: remove UserRole, fully replaced by AppMode + driverVehicleType"
```

---

### Task 9: Manual verification on the emulator

**Files:** none (verification only).

- [ ] **Step 1: Build and install**

Use the `run-yame` skill (or manually): `flutter build apk --debug`, install on the `Yame_Pixel` emulator.

- [ ] **Step 2: Scenario — pure client, never registered as driver**

Sign up via "Client". In Profil, confirm only "Devenir chauffeur" shows (no switch button).

- [ ] **Step 3: Scenario — becomes a driver from Profil, gets approved, switches**

From that same client account, tap "Devenir chauffeur" → pick "Voiture" → complete `VehicleRegistrationWizard`. In the `yame-admin` panel (`/chauffeurs`, tab "En attente"), approve the driver. Back in the app's Profil tab, confirm "Passer en mode chauffeur" now appears; tap it and confirm `HomeScreen` switches to `DriverHomeScreen`. From there, confirm the Profil tab (reachable once back in client mode) shows "Passer en mode client" and switching back works.

- [ ] **Step 4: Scenario — switch blocked while client has an active ride**

As the client, request a ride (status `searching`, no driver yet). Attempt to switch to driver mode from Profil (if this account has driver capability) — confirm the button is disabled with the blocked message. Cancel the ride, confirm the button re-enables.

- [ ] **Step 5: Scenario — switch blocked while driver has an accepted ride**

With a second test account (driver), accept the client's ride. Confirm the driver's own switch-to-client button (if reachable — Profil may not be in the driver's tab bar; check `DriverHomeScreen`'s own affordances) is disabled while `_activeRideId` is set. Complete the ride, confirm it re-enables.

- [ ] **Step 6: Scenario — app restart mid-ride recovers the block**

While a ride is `accepted`, force-stop the app on both accounts and reopen. Confirm the switch is still correctly blocked (proves the Task 6 recovery logic works, not just the in-memory happy path).

- [ ] **Step 7: Clean up test accounts**

Delete the Firebase Auth test accounts created during this verification via the Firebase console (no CLI tooling for this without a service-account key, per project convention) and note their replacements in project memory if the user asks.
