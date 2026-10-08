import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/moderation_notice.dart';
import '../../core/widgets/nav_bar_item.dart';
import '../../models/moderation.dart';
import '../../models/vehicle_type.dart';
import '../booking/booking_screen.dart';
import 'client_home_tab.dart';
import 'messages_tab.dart';
import 'profil_screen.dart';
import '../../repositories/user_repository.dart';

/// Coque avec barre de navigation pour l'espace client :
/// Accueil / Courses / Messages / Profil.
class ClientShell extends StatefulWidget {
  const ClientShell({super.key, required this.name});

  final String name;

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _index = 0;
  VehicleType _vehicleType = VehicleType.car;

  void _openBookingWith(VehicleType type) {
    setState(() {
      _vehicleType = type;
      _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ClientHomeTab(name: widget.name, onSelectVehicle: _openBookingWith),
      BookingScreen(key: ValueKey(_vehicleType), initialVehicleType: _vehicleType),
      MessagesTab(onViewRide: () => setState(() => _index = 1)),
      const ProfilScreen(),
    ];

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: uid == null
          ? null
          : UserRepository().watchUser(uid),
      builder: (context, snapshot) {
        final rideLocked = snapshot.data?.data()?['clientActiveRideId'] != null;
        final moderation = ModerationState.forClient(snapshot.data?.data());

        return Scaffold(
          body: Column(
            children: [
              if (moderation != null)
                SafeArea(bottom: false, child: ModerationBanner(state: moderation)),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: moderation != null,
                  child: IndexedStack(index: _index, children: tabs),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _NavBar(
            index: _index,
            locked: rideLocked,
            onChanged: (value) => setState(() => _index = value),
          ),
        );
      },
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.locked, required this.onChanged});

  final int index;

  /// Une course client est en cours : on reste sur l'onglet Courses plutôt
  /// que de laisser rater une mise à jour de statut en changeant d'écran.
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          NavBarItem(
            icon: Icons.home_rounded,
            label: AppStrings.navHome,
            selected: index == 0,
            onTap: () => _select(context, 0),
          ),
          NavBarItem(
            icon: Icons.list_alt_rounded,
            label: AppStrings.navRides,
            selected: index == 1,
            onTap: () => _select(context, 1),
          ),
          _CenterButton(onTap: () => _select(context, 1)),
          NavBarItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: AppStrings.navMessages,
            selected: index == 2,
            onTap: () => _select(context, 2),
          ),
          NavBarItem(
            icon: Icons.person_outline_rounded,
            label: AppStrings.navProfile,
            selected: index == 3,
            onTap: () => _select(context, 3),
          ),
        ],
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -14),
      child: Material(
        color: AppColors.accent,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: Text(
                'Y',
                style: TextStyle(
                  color: AppColors.background,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
