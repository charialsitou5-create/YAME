import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.step, required this.labels});

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final passed = (i ~/ 2) < step;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: passed ? AppColors.accent : AppColors.border,
            ),
          );
        }
        final index = i ~/ 2;
        final active = index == step;
        final done = index < step;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (active || done)
                    ? AppColors.accent
                    : AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: (active || done)
                      ? AppColors.background
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 80,
              child: Text(
                labels[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? AppColors.accentBright
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
