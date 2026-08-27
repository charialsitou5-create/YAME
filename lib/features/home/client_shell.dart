import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/vehicle_type.dart';
import '../booking/booking_screen.dart';
import 'client_home_tab.dart';
import 'messages_tab.dart';
import 'profil_screen.dart';

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

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: _NavBar(
        index: _index,
        onChanged: (value) => setState(() => _index = value),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

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
          _NavItem(
            icon: Icons.home_rounded,
            label: AppStrings.navHome,
            selected: index == 0,
            onTap: () => onChanged(0),
          ),
          _NavItem(
            icon: Icons.list_alt_rounded,
            label: AppStrings.navRides,
            selected: index == 1,
            onTap: () => onChanged(1),
          ),
          _CenterButton(onTap: () => onChanged(1)),
          _NavItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: AppStrings.navMessages,
            selected: index == 2,
            onTap: () => onChanged(2),
          ),
          _NavItem(
            icon: Icons.person_outline_rounded,
            label: AppStrings.navProfile,
            selected: index == 3,
            onTap: () => onChanged(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
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
