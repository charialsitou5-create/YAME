import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Un item de barre de navigation basse, partagé entre les coques client et
/// chauffeur (`ClientShell`, `DriverShell`) pour qu'elles restent identiques
/// visuellement. `onTap` est toujours appelé — c'est à l'appelant de décider
/// quoi faire (changer d'onglet, ou refuser avec un message si un onglet est
/// verrouillé, par ex. pendant une course en cours).
class NavBarItem extends StatelessWidget {
  const NavBarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 30,
              alignment: Alignment.center,
              decoration: selected
                  ? BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                    )
                  : null,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
