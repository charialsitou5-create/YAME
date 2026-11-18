import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

/// En-tête de l'écran chauffeur (maquette du 2026-10-21) : logo Yame et
/// cloche sur la première ligne, puis avatar, salutation, rôle et pastille
/// en ligne/hors ligne empilés sous le nom.
class DriverHeader extends StatelessWidget {
  const DriverHeader({
    super.key,
    required this.driverName,
    required this.online,
  });

  final String driverName;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final statusColor = online ? AppColors.success : AppColors.textDisabled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/images/logo_yame.png', width: 34, height: 34),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'YAME',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.accentBright,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.textPrimary,
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.accent,
                child: Text(
                  driverName.isNotEmpty ? driverName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.background,
                    fontWeight: FontWeight.w700,
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
                      '${AppStrings.homeGreeting} $driverName',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      AppStrings.driverDashboardTitle,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              online
                                  ? AppStrings.driverOnline
                                  : AppStrings.driverOffline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: online
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
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
        ],
      ),
    );
  }
}
