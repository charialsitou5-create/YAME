import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/app_user.dart';
import '../../routes/app_routes.dart';
import '../support/my_reports_screen.dart';
import '../support/report_issue_screen.dart';
import 'personal_info_screen.dart';
import 'settings_screen.dart';
import '../../repositories/user_repository.dart';
import 'profil/driver_section.dart';
import 'profil/profile_card.dart';
import 'profil/settings_row.dart';

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
              ProfileCard(
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
                    child: ActivityStat(
                      icon: Icons.shopping_bag_outlined,
                      label: AppStrings.profileStatCourses,
                      onTap: () => _showComingSoon(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ActivityStat(
                      icon: Icons.calendar_today_outlined,
                      label: AppStrings.profileStatReservations,
                      onTap: () => _showComingSoon(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ActivityStat(
                      icon: Icons.star_outline_rounded,
                      label: AppStrings.profileStatFavorites,
                      onTap: () => _showComingSoon(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ActivityStat(
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
                    SettingsRow(
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
                    const RowDivider(),
                    SettingsRow(
                      icon: Icons.credit_card_outlined,
                      title: AppStrings.profilePaymentMethods,
                      subtitle: AppStrings.profilePaymentMethodsSubtitle,
                      onTap: () => _showComingSoon(context),
                    ),
                    const RowDivider(),
                    SettingsRow(
                      icon: Icons.location_on_outlined,
                      title: AppStrings.profileAddresses,
                      subtitle: AppStrings.profileAddressesSubtitle,
                      onTap: () => _showComingSoon(context),
                    ),
                    const RowDivider(),
                    SettingsRow(
                      icon: Icons.card_giftcard_outlined,
                      title: AppStrings.profileInviteFriend,
                      subtitle: AppStrings.profileInviteFriendSubtitle,
                      onTap: () => _showComingSoon(context),
                    ),
                    const RowDivider(),
                    SettingsRow(
                      icon: Icons.settings_outlined,
                      title: AppStrings.profileSettings,
                      subtitle: AppStrings.profileSettingsSubtitle,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                    const RowDivider(),
                    SettingsRow(
                      icon: Icons.support_agent_outlined,
                      title: AppStrings.profileHelp,
                      subtitle: AppStrings.profileHelpSubtitle,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReportIssueScreen(),
                        ),
                      ),
                    ),
                    if (uid != null) ...[
                      const RowDivider(),
                      SettingsRow(
                        icon: Icons.forum_outlined,
                        title: AppStrings.myReportsEntry,
                        subtitle: AppStrings.myReportsTitle,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => MyReportsScreen(uid: uid)),
                        ),
                      ),
                    ],
                    const RowDivider(),
                    SettingsRow(
                      icon: Icons.info_outline_rounded,
                      title: AppStrings.profileAbout,
                      subtitle: AppStrings.profileAboutVersion,
                      onTap: () => _showAbout(context),
                    ),
                    if (uid != null && user != null) ...[
                      const RowDivider(),
                      DriverSection(uid: uid, user: user),
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
              SettingsRow(
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
