import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../routes/app_routes.dart';

/// Affiché à la place de [DriverHomeScreen] tant que l'inscription du
/// véhicule d'un chauffeur n'a pas été validée (ou a été refusée) par
/// un admin — `driver_profiles/{uid}.status`.
class DriverStatusScreen extends StatelessWidget {
  const DriverStatusScreen({super.key, required this.rejected});

  final bool rejected;

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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: AppStrings.logout,
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
                    color: rejected
                        ? AppColors.error.withValues(alpha: 0.4)
                        : AppColors.border,
                  ),
                ),
                child: Icon(
                  rejected
                      ? Icons.error_outline_rounded
                      : Icons.hourglass_top_rounded,
                  size: 36,
                  color: rejected ? AppColors.error : AppColors.accentBright,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                rejected
                    ? AppStrings.driverRejectedTitle
                    : AppStrings.driverPendingTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge
                    ?.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 12),
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
    );
  }
}
