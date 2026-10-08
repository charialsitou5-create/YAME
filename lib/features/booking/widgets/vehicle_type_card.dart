import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/vehicle_type.dart';

class VehicleTypeCard extends StatelessWidget {
  const VehicleTypeCard({
    super.key,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final VehicleType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.12)
          : AppColors.fieldFill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  type == VehicleType.car
                      ? Icons.directions_car_filled_rounded
                      : Icons.two_wheeler_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                type.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
