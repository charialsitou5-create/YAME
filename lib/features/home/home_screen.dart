import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../driver/driver_home_screen.dart';
import '../driver/driver_intro_screen.dart';
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
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        if (data == null) return const SizedBox.shrink();

        final user = AppUser.fromMap(uid, data);
        if (user.role == UserRole.client) {
          return ClientShell(name: user.name);
        }
        if (!user.vehicleRegistered) {
          return DriverIntroScreen(role: user.role);
        }
        return DriverHomeScreen(role: user.role, driverName: user.name);
      },
    );
  }
}
