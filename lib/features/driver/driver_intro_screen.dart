import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/vehicle_type.dart';
import '../../routes/app_routes.dart';
import 'vehicle_registration_wizard.dart';

/// Écran affiché à un chauffeur (voiture ou moto) tant qu'il n'a pas
/// terminé l'enregistrement de son véhicule : rappelle comment fonctionne
/// la rémunération avant de lancer l'assistant en 3 étapes.
class DriverIntroScreen extends StatelessWidget {
  const DriverIntroScreen({super.key, required this.vehicleType});

  final VehicleType vehicleType;

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.onboarding, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/skyline_hero.jpg', fit: BoxFit.cover),
          const DecoratedBox(decoration: BoxDecoration(color: Color(0xCC0B0B10))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout_rounded),
                      tooltip: AppStrings.logout,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '${AppStrings.driverIntroPrefix}\n'),
                        TextSpan(
                          text: vehicleType == VehicleType.car
                              ? AppStrings.roleDriverCar
                              : AppStrings.roleDriverMoto,
                          style: const TextStyle(color: AppColors.accentBright),
                        ),
                      ],
                    ),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
                  ),
                  const SizedBox(height: 10),
                  Text(AppStrings.driverIntroSubtitle, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 32),
                  Text(
                    AppStrings.driverIntroHowItWorks,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: AppColors.accentBright),
                  ),
                  const SizedBox(height: 18),
                  const _HowItWorksRow(
                    icon: Icons.account_balance_wallet_outlined,
                    text: AppStrings.driverIntroStep1,
                  ),
                  const SizedBox(height: 16),
                  const _HowItWorksRow(icon: Icons.mail_outline_rounded, text: AppStrings.driverIntroStep2),
                  const SizedBox(height: 16),
                  const _HowItWorksRow(
                    icon: Icons.percent_rounded,
                    text: AppStrings.driverIntroStep3,
                  ),
                  const SizedBox(height: 16),
                  const _HowItWorksRow(
                    icon: Icons.verified_user_outlined,
                    text: AppStrings.driverIntroStep4,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VehicleRegistrationWizard(vehicleType: vehicleType),
                        ),
                      ),
                      child: const Text(AppStrings.driverIntroCta),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksRow extends StatelessWidget {
  const _HowItWorksRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.accentBright, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      ],
    );
  }
}
