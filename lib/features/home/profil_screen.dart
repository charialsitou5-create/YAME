import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/app_mode.dart';
import '../../models/app_user.dart';
import '../../models/vehicle_type.dart';
import '../../routes/app_routes.dart';
import '../driver/recharge_screen.dart';
import '../driver/vehicle_registration_wizard.dart';
import '../support/report_issue_screen.dart';
import 'personal_info_screen.dart';
import 'settings_screen.dart';
import '../../repositories/driver_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/wallet_repository.dart';

/// Onglet Profil : identité, activités, réglages du compte.
class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.socialAuthComingSoon)),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppStrings.appName,
      applicationVersion: AppStrings.profileAboutVersion,
      applicationLegalese: AppStrings.slogan,
    );
  }

  Future<void> _logout(BuildContext context) async {
    // Un chauffeur qui se déconnecte en étant en ligne doit repasser hors
    // ligne côté Firestore (sinon `driverOnline` reste vrai indéfiniment et
    // le dispatch pourrait continuer à le considérer candidat — voir
    // `yame-admin/lib/dispatch/workflow.ts`). Le flux GPS local, lui, s'arrête
    // tout seul via `DriverTrackingService.stopTracking()` au `dispose()` de
    // `DriverHomeScreen` quand tout l'arbre de widgets est démonté ci-dessous.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await UserRepository().getUser(uid);
      final data = doc.data();
      if (data?['activeMode'] == 'driver' && data?['driverOnline'] == true) {
        await UserRepository().updateUser(uid, {'driverOnline': false});
      }
    }
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.onboarding, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return SafeArea(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: uid == null
            ? null
            : UserRepository().watchUser(uid),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final user = (uid != null && data != null)
              ? AppUser.fromMap(uid, data)
              : null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.navProfile,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const Icon(Icons.notifications_none_rounded, size: 26),
                ],
              ),
              const SizedBox(height: 20),
              _ProfileCard(
                name: user?.name ?? '',
                phone: user?.phone ?? '',
                email: user?.email,
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.profileActivities,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ActivityStat(
                      icon: Icons.shopping_bag_outlined,
                      label: AppStrings.profileStatCourses,
                      onTap: () => _showComingSoon(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActivityStat(
                      icon: Icons.calendar_today_outlined,
                      label: AppStrings.profileStatReservations,
                      onTap: () => _showComingSoon(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActivityStat(
                      icon: Icons.star_outline_rounded,
                      label: AppStrings.profileStatFavorites,
                      onTap: () => _showComingSoon(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActivityStat(
                      icon: Icons.description_outlined,
                      label: AppStrings.profileStatPayments,
                      onTap: () => _showComingSoon(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Icons.person_outline_rounded,
                      title: AppStrings.profilePersonalInfo,
                      subtitle: AppStrings.profilePersonalInfoSubtitle,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PersonalInfoScreen(
                            name: user?.name ?? '',
                            phone: user?.phone ?? '',
                            email: user?.email,
                          ),
                        ),
                      ),
                    ),
                    const _RowDivider(),
                    _SettingsRow(
                      icon: Icons.credit_card_outlined,
                      title: AppStrings.profilePaymentMethods,
                      subtitle: AppStrings.profilePaymentMethodsSubtitle,
                      onTap: () => _showComingSoon(context),
                    ),
                    const _RowDivider(),
                    _SettingsRow(
                      icon: Icons.location_on_outlined,
                      title: AppStrings.profileAddresses,
                      subtitle: AppStrings.profileAddressesSubtitle,
                      onTap: () => _showComingSoon(context),
                    ),
                    const _RowDivider(),
                    _SettingsRow(
                      icon: Icons.card_giftcard_outlined,
                      title: AppStrings.profileInviteFriend,
                      subtitle: AppStrings.profileInviteFriendSubtitle,
                      onTap: () => _showComingSoon(context),
                    ),
                    const _RowDivider(),
                    _SettingsRow(
                      icon: Icons.settings_outlined,
                      title: AppStrings.profileSettings,
                      subtitle: AppStrings.profileSettingsSubtitle,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                    const _RowDivider(),
                    _SettingsRow(
                      icon: Icons.support_agent_outlined,
                      title: AppStrings.profileHelp,
                      subtitle: AppStrings.profileHelpSubtitle,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReportIssueScreen(),
                        ),
                      ),
                    ),
                    const _RowDivider(),
                    _SettingsRow(
                      icon: Icons.info_outline_rounded,
                      title: AppStrings.profileAbout,
                      subtitle: AppStrings.profileAboutVersion,
                      onTap: () => _showAbout(context),
                    ),
                    if (uid != null && user != null) ...[
                      const _RowDivider(),
                      _DriverSection(uid: uid, user: user),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.profilePremiumTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppStrings.profilePremiumBody,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _showComingSoon(context),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: const Text(AppStrings.profilePremiumCta),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SettingsRow(
                icon: Icons.logout_rounded,
                iconColor: AppColors.error,
                title: AppStrings.profileLogout,
                titleColor: AppColors.error,
                onTap: () => _logout(context),
                background: AppColors.surface,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.phone,
    required this.email,
  });

  final String name;
  final String phone;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentBright, width: 2),
            ),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.background,
                fontWeight: FontWeight.w800,
                fontSize: 26,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email != null && email!.isNotEmpty)
                  Text(
                    email!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.accentBright,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        AppStrings.profileMember,
                        style: const TextStyle(
                          color: AppColors.accentBright,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityStat extends StatelessWidget {
  const _ActivityStat({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.accent, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    this.background,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Color? titleColor;
  final Color? background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.textPrimary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );

    if (background == null) return row;
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: row,
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.border,
    );
  }
}

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

    await UserRepository().updateUser(uid, {
      'driverVehicleType': type.name,
    });
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VehicleRegistrationWizard(vehicleType: type)),
    );
  }

  Future<void> _switchMode(AppMode newMode) {
    return UserRepository().updateUser(uid, {
      'activeMode': newMode.firestoreValue,
    });
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final vehicleType = user.driverVehicleType;

    // Simple option parmi les autres réglages, pas une bannière incitative :
    // devenir chauffeur reste un choix qu'on va chercher, pas quelque chose
    // qu'on pousse en avant sur le profil.
    if (vehicleType == null) {
      return _SettingsRow(
        icon: Icons.directions_car_filled_rounded,
        title: AppStrings.profileBecomeDriverTitle,
        subtitle: AppStrings.profileBecomeDriverSubtitle,
        onTap: () => _pickVehicleType(context),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DriverRepository().watchProfile(uid),
      builder: (context, snapshot) {
        final status = snapshot.data?.data()?['status'] as String? ?? 'pending_verification';

        if (status != 'approved') {
          final title = status == 'rejected'
              ? AppStrings.driverRejectedTitle
              : AppStrings.driverPendingTitle;
          final body = status == 'rejected'
              ? AppStrings.driverRejectedBody
              : AppStrings.driverPendingBody;
          return _SettingsRow(
            icon: Icons.directions_car_filled_rounded,
            title: title,
            subtitle: body,
            onTap: () => _showSnack(context, body),
          );
        }

        final blocked = user.activeMode == AppMode.client
            ? user.clientActiveRideId != null
            : user.driverActiveRideId != null;
        final targetMode = user.activeMode == AppMode.client ? AppMode.driver : AppMode.client;
        final label = targetMode == AppMode.driver
            ? AppStrings.profileSwitchToDriver
            : AppStrings.profileSwitchToClient;

        return Column(
          children: [
            _DriverWalletRow(uid: uid),
            const _RowDivider(),
            _SettingsRow(
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
class _DriverWalletRow extends StatelessWidget {
  const _DriverWalletRow({required this.uid});

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
                child: _WalletAmount(
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
                child: _WalletAmount(
                  icon: Icons.savings_outlined,
                  label: AppStrings.driverDashboardEarningsAccount,
                  amount: earnings,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(AppStrings.socialAuthComingSoon)),
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

class _WalletAmount extends StatelessWidget {
  const _WalletAmount({
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
