import 'package:flutter/material.dart';

import '../../models/moderation.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';

String moderationDateLabel(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year}';
}

/// Texte détaillé (motif, échéance, contact support) d'une restriction.
class ModerationDetails extends StatelessWidget {
  const ModerationDetails({super.key, required this.state, this.textAlign});

  final ModerationState state;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.reason != null)
          Text('${AppStrings.moderationReasonLabel}${state.reason}',
              textAlign: textAlign, style: style),
        if (state.until != null && state.kind == ModerationKind.suspended)
          Text('${AppStrings.moderationUntil}${moderationDateLabel(state.until!)}',
              textAlign: textAlign, style: style),
        const SizedBox(height: 8),
        Text(AppStrings.moderationContactSupport, textAlign: textAlign, style: style),
      ],
    );
  }
}

/// Bandeau compact affiché en haut de l'espace client restreint.
class ModerationBanner extends StatelessWidget {
  const ModerationBanner({super.key, required this.state});

  final ModerationState state;

  @override
  Widget build(BuildContext context) {
    final title = state.kind == ModerationKind.blocked
        ? AppStrings.moderationBlockedTitle
        : AppStrings.moderationSuspendedTitle;
    return Material(
      color: AppColors.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.block_rounded, size: 20, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(AppStrings.moderationClientCannotRequest,
                      style: Theme.of(context).textTheme.bodyMedium),
                  if (state.reason != null)
                    Text('${AppStrings.moderationReasonLabel}${state.reason}',
                        style: Theme.of(context).textTheme.bodyMedium),
                  if (state.until != null && state.kind == ModerationKind.suspended)
                    Text('${AppStrings.moderationUntil}${moderationDateLabel(state.until!)}',
                        style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
