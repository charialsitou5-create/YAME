import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/app_mode.dart';
import '../../../models/app_user.dart';
import '../../../models/vehicle_type.dart';
import '../../driver/recharge_screen.dart';
import '../../driver/vehicle_registration_wizard.dart';
import '../../../repositories/driver_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../repositories/wallet_repository.dart';
import 'settings_row.dart';

class DriverSection extends StatelessWidget {
  const DriverSection({super.key, required this.uid, required this.user});

  final String uid;
  final AppUser user;

  Future<void> _pickVehicleType(BuildContext context) async {
    final type = await showModalBottomSheet<VehicleType>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const VehicleTypeSheet(),
    );
    if (type == null || !context.mounted) return;

    await UserRepository().updateUser(uid, {'driverVehicleType': type.name});
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VehicleRegistrationWizard(vehicleType: type),
      ),
    );
  }

  Future<void> _switchMode(AppMode newMode) {
    return UserRepository().updateUser(uid, {
      'activeMode': newMode.firestoreValue,
    });
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final vehicleType = user.driverVehicleType;

    // Simple option parmi les autres réglages, pas une bannière incitative :
    // devenir chauffeur reste un choix qu'on va chercher, pas quelque chose
    // qu'on pousse en avant sur le profil.
    if (vehicleType == null) {
      return SettingsRow(
        icon: Icons.directions_car_filled_rounded,
        title: AppStrings.profileBecomeDriverTitle,
        subtitle: AppStrings.profileBecomeDriverSubtitle,
        onTap: () => _pickVehicleType(context),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DriverRepository().watchProfile(uid),
      builder: (context, snapshot) {
        final status =
            snapshot.data?.data()?['status'] as String? ??
            'pending_verification';

        if (status != 'approved') {
          final title = status == 'rejected'
              ? AppStrings.driverRejectedTitle
              : AppStrings.driverPendingTitle;
          final body = status == 'rejected'
              ? AppStrings.driverRejectedBody
              : AppStrings.driverPendingBody;
          return SettingsRow(
            icon: Icons.directions_car_filled_rounded,
            title: title,
            subtitle: body,
            onTap: () => _showSnack(context, body),
          );
        }

        final blocked = user.activeMode == AppMode.client
            ? user.clientActiveRideId != null
            : user.driverActiveRideId != null;
        final targetMode = user.activeMode == AppMode.client
            ? AppMode.driver
            : AppMode.client;
        final label = targetMode == AppMode.driver
            ? AppStrings.profileSwitchToDriver
            : AppStrings.profileSwitchToClient;

        return Column(
          children: [
            DriverWalletRow(uid: uid),
            const RowDivider(),
            SettingsRow(
              icon: Icons.sync_alt_rounded,
              title: label,
              subtitle: blocked ? AppStrings.profileSwitchBlocked : null,
              onTap: () => blocked
                  ? _showSnack(context, AppStrings.profileSwitchBlocked)
                  : _switchMode(targetMode),
            ),
          ],
        );
      },
    );
  }
}

/// Rappel du solde chauffeur dans l'onglet Profil — mêmes chiffres que la
/// carte de la page Accueil, pour pouvoir les consulter depuis l'un ou
/// l'autre écran sans dépendre uniquement du dashboard chauffeur.
class DriverWalletRow extends StatelessWidget {
  const DriverWalletRow({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: WalletRepository().watchWallet(uid),
      builder: (context, snapshot) {
        final balance = snapshot.data?.data()?['balance'] as int? ?? 0;
        final earnings = snapshot.data?.data()?['earningsBalance'] as int? ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: WalletAmount(
                  icon: Icons.bolt_rounded,
                  label: AppStrings.driverDashboardRechargeAccount,
                  amount: balance,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RechargeScreen()),
                  ),
                  actionLabel: AppStrings.driverDashboardRecharge,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              const SizedBox(width: 16),
              Expanded(
                child: WalletAmount(
                  icon: Icons.savings_outlined,
                  label: AppStrings.driverDashboardEarningsAccount,
                  amount: earnings,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(AppStrings.socialAuthComingSoon),
                    ),
                  ),
                  actionLabel: AppStrings.driverDashboardSeeEarnings,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class WalletAmount extends StatelessWidget {
  const WalletAmount({
    super.key,
    required this.icon,
    required this.label,
    required this.amount,
    required this.onTap,
    required this.actionLabel,
  });

  final IconData icon;
  final String label;
  final int amount;
  final VoidCallback onTap;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$amount FCFA',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            actionLabel,
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class VehicleTypeSheet extends StatelessWidget {
  const VehicleTypeSheet({super.key});

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
              leading: const Icon(
                Icons.directions_car_filled_rounded,
                color: AppColors.accent,
              ),
              title: const Text(AppStrings.roleDriverCar),
              onTap: () => Navigator.of(context).pop(VehicleType.car),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.two_wheeler_rounded,
                color: AppColors.accent,
              ),
              title: const Text(AppStrings.roleDriverMoto),
              onTap: () => Navigator.of(context).pop(VehicleType.moto),
            ),
          ],
        ),
      ),
    );
  }
}
