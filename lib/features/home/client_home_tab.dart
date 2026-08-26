import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/vehicle_type.dart';

/// Contenu de l'onglet Accueil pour un client : salutation, bannière
/// paiement, et choix du type de service (mène à l'onglet Courses).
class ClientHomeTab extends StatelessWidget {
  const ClientHomeTab({super.key, required this.name, required this.onSelectVehicle});

  final String name;
  final ValueChanged<VehicleType> onSelectVehicle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '${AppStrings.homeGreeting}\n'),
                        TextSpan(
                          text: name.isNotEmpty ? '$name 👋' : '👋',
                          style: const TextStyle(color: AppColors.accentBright),
                        ),
                      ],
                    ),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                  ),
                ),
                const Icon(Icons.notifications_none_rounded, size: 28),
              ],
            ),
            const SizedBox(height: 8),
            Text(AppStrings.homeQuestion, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_outline_rounded, color: AppColors.accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.homePromoTitle,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppStrings.homePromoBody,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(AppStrings.homeServiceTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            _ServiceTile(
              image: 'assets/images/vehicle_car.jpg',
              icon: Icons.directions_car_filled_rounded,
              title: AppStrings.homeServiceCarTitle,
              body: AppStrings.homeServiceCarBody,
              onTap: () => onSelectVehicle(VehicleType.car),
            ),
            const SizedBox(height: 14),
            _ServiceTile(
              image: 'assets/images/vehicle_moto.jpg',
              icon: Icons.two_wheeler_rounded,
              title: AppStrings.homeServiceMotoTitle,
              body: AppStrings.homeServiceMotoBody,
              onTap: () => onSelectVehicle(VehicleType.moto),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.image,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final String image;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(image, width: 84, height: 64, fit: BoxFit.cover),
              ),
              const SizedBox(width: 14),
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: AppColors.background),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
