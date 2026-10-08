import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

class ImagesStep extends StatelessWidget {
  const ImagesStep({
    super.key,
    required this.isCar,
    required this.labels,
    required this.photos,
    required this.onPick,
  });

  final bool isCar;
  final List<String> labels;
  final Map<String, File?> photos;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final overview = isCar ? null : AppStrings.wizardPhotoOverview;
    final gridLabels = labels
        .where((l) => l != overview)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Images '),
              TextSpan(
                text: isCar ? 'du véhicule' : 'de la moto',
                style: const TextStyle(color: AppColors.accentBright),
              ),
            ],
          ),
          style: Theme.of(context).textTheme.displayLarge
              ?.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 6),
        Text(
          isCar
              ? AppStrings.wizardImagesVehicleSubtitle
              : AppStrings.wizardImagesMotoSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.85,
          children: gridLabels
              .map(
                (label) => PhotoSlot(
                  label: label,
                  file: photos[label],
                  onTap: () => onPick(label),
                ),
              )
              .toList(growable: false),
        ),
        if (overview != null) ...[
          const SizedBox(height: 14),
          PhotoSlot(
            label: overview,
            file: photos[overview],
            onTap: () => onPick(overview),
            height: 160,
          ),
        ],
      ],
    );
  }
}

class PhotoSlot extends StatelessWidget {
  const PhotoSlot({
    super.key,
    required this.label,
    required this.file,
    required this.onTap,
    this.height,
  });

  final String label;
  final File? file;
  final VoidCallback onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Expanded(
            child: file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      file!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text(
              AppStrings.wizardAddPhoto,
              style: TextStyle(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ],
      ),
    );
  }
}
