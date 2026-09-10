import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/app_mode.dart';
import '../../models/app_user.dart';
import '../../models/vehicle_type.dart';
import '../../routes/app_routes.dart';
import '../driver/vehicle_registration_wizard.dart';
import '../support/report_issue_screen.dart';

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
            : FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
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
              if (uid != null && user != null) ...[
                _DriverSection(uid: uid, user: user),
                const SizedBox(height: 16),
              ],
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
                      onTap: () => _showComingSoon(context),
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
                      onTap: () => _showComingSoon(context),
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
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
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
