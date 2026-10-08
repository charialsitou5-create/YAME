import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/moderation_notice.dart';
import '../../models/moderation.dart';
import '../../routes/app_routes.dart';
import '../home/profil_screen.dart';

/// Affiché à la place de [DriverHomeScreen] tant que l'inscription du
/// véhicule d'un chauffeur n'a pas été validée (ou a été refusée) par
/// un admin — `driver_profiles/{uid}.status`.
class DriverStatusScreen extends StatelessWidget {
  const DriverStatusScreen({super.key, required this.rejected, this.suspension});

  final bool rejected;

  /// Si non nul, le chauffeur est suspendu : avis avec motif/échéance, et
  /// aucun accès au mode en ligne.
  final ModerationState? suspension;

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.onboarding, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const Scaffold(
                                  body: ProfilScreen(),
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.person_outline_rounded),
                            tooltip: AppStrings.navProfile,
                          ),
                          IconButton(
                            onPressed: () => _logout(context),
                            icon: const Icon(Icons.logout_rounded),
                            tooltip: AppStrings.logout,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (rejected || suspension != null)
                              ? AppColors.error.withValues(alpha: 0.4)
                              : AppColors.border,
                        ),
                      ),
                      child: Icon(
                        suspension != null
                            ? Icons.block_rounded
                            : rejected
                            ? Icons.error_outline_rounded
                            : Icons.hourglass_top_rounded,
                        size: 36,
                        color: (rejected || suspension != null)
                            ? AppColors.error
                            : AppColors.accentBright,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      suspension != null
                          ? AppStrings.moderationSuspendedTitle
                          : rejected
                          ? AppStrings.driverRejectedTitle
                          : AppStrings.driverPendingTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayLarge
                          ?.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 12),
                    if (suspension != null) ...[
                      Text(
                        AppStrings.moderationDriverCannotGoOnline,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      ModerationDetails(state: suspension!, textAlign: TextAlign.center),
                    ] else
                      Text(
                        rejected
                            ? AppStrings.driverRejectedBody
                            : AppStrings.driverPendingBody,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
