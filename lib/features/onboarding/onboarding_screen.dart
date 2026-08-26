import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_role.dart';
import '../../routes/app_routes.dart';

/// Écran d'accueil de marque et sélection de profil, sur la photo du
/// bord de mer — le point d'entrée unique de l'application.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/skyline_hero.jpg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC0B0B10),
                  Color(0x330B0B10),
                  Color(0xE60B0B10),
                  Color(0xFF0B0B10),
                ],
                stops: [0, 0.32, 0.62, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Bienvenue\nchez '),
                        TextSpan(
                          text: 'Yame',
                          style: TextStyle(color: AppColors.accentBright),
                        ),
                        const TextSpan(text: ' !'),
                      ],
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.displayLarge?.copyWith(fontSize: 42),
                  ),
                  const SizedBox(height: 12),
                  Text(AppStrings.slogan, style: Theme.of(context).textTheme.bodyLarge),
                  const Spacer(),
                  Text(
                    'Que souhaitez-vous faire ?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    role: UserRole.client,
                    icon: Icons.person_rounded,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.signup, arguments: UserRole.client),
                  ),
                  const SizedBox(height: 14),
                  _RoleCard(
                    role: UserRole.chauffeurVoiture,
                    icon: Icons.directions_car_filled_rounded,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.signup, arguments: UserRole.chauffeurVoiture),
                  ),
                  const SizedBox(height: 14),
                  _RoleCard(
                    role: UserRole.chauffeurMoto,
                    icon: Icons.two_wheeler_rounded,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.signup, arguments: UserRole.chauffeurMoto),
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyLarge,
                        children: [
                          const TextSpan(text: 'Déjà un compte ? '),
                          TextSpan(
                            text: 'Se connecter',
                            style: const TextStyle(
                              color: AppColors.accentBright,
                              fontWeight: FontWeight.w700,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => Navigator.of(context).pushNamed(AppRoutes.login),
                          ),
                        ],
                      ),
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.icon, required this.onTap});

  final UserRole role;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.textPrimary,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.background),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.label,
                      style: const TextStyle(
                        color: AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      role.description,
                      style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.lightTextPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
