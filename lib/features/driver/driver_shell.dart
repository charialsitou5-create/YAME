import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/nav_bar_item.dart';
import '../../models/vehicle_type.dart';
import '../home/profil_screen.dart';
import 'driver_home_screen.dart';
import '../../repositories/user_repository.dart';

/// Coque avec barre de navigation pour l'espace chauffeur : Accueil / Profil
/// — miroir de `ClientShell` pour que les deux rôles se ressemblent. Regroupe
/// dans l'onglet Profil (partagé avec le client) ce qui était avant 3 icônes
/// séparées dans le header chauffeur (aide/incident, profil, déconnexion) ;
/// seul le portefeuille reste propre à l'onglet Accueil (carte "Recharger").
class DriverShell extends StatefulWidget {
  const DriverShell({super.key, required this.vehicleType, required this.driverName});

  final VehicleType vehicleType;
  final String driverName;

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DriverHomeScreen(vehicleType: widget.vehicleType, driverName: widget.driverName),
      const ProfilScreen(),
    ];

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: uid == null
          ? null
          : UserRepository().watchUser(uid),
      builder: (context, snapshot) {
        final rideLocked = snapshot.data?.data()?['driverActiveRideId'] != null;

        return Scaffold(
          body: IndexedStack(index: _index, children: tabs),
          bottomNavigationBar: _DriverNavBar(
            index: _index,
            locked: rideLocked,
            onChanged: (value) => setState(() => _index = value),
          ),
        );
      },
    );
  }
}

class _DriverNavBar extends StatelessWidget {
  const _DriverNavBar({required this.index, required this.locked, required this.onChanged});

  final int index;

  /// Une course chauffeur est en cours : on reste sur l'onglet Accueil (où
  /// vit le suivi de la course) plutôt que de laisser rater une étape en
  /// changeant d'écran.
  final bool locked;
  final ValueChanged<int> onChanged;

  void _select(BuildContext context, int value) {
    if (locked && value != index) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.navLockedDuringRide)),
      );
      return;
    }
    onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          NavBarItem(
            icon: Icons.home_rounded,
            label: AppStrings.navHome,
            selected: index == 0,
            onTap: () => _select(context, 0),
          ),
          NavBarItem(
            icon: Icons.person_outline_rounded,
            label: AppStrings.navProfile,
            selected: index == 1,
            onTap: () => _select(context, 1),
          ),
        ],
      ),
    );
  }
}
