import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../routes/app_routes.dart';

/// Écran d'accueil provisoire — la réservation de course viendra ici.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: AppStrings.logout,
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.onboarding,
              (route) => false,
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 64, color: AppColors.textSecondary),
              const SizedBox(height: 20),
              Text(AppStrings.homeWelcome, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                AppStrings.homeComingSoon,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
