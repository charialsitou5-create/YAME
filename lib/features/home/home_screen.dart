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
/// selon le rôle du profil chargé depuis Firestore.
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
