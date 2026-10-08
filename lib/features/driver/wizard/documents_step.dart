import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

class DocumentsStep extends StatelessWidget {
  const DocumentsStep({
    super.key,
    required this.isCar,
    required this.registrationCard,
    required this.license,
    required this.onPickRegistration,
    required this.onPickLicense,
  });

  final bool isCar;
  final File? registrationCard;
  final File? license;
  final VoidCallback onPickRegistration;
  final VoidCallback onPickLicense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.wizardDocumentsTitle,
          style: Theme.of(context).textTheme.displayLarge
              ?.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.wizardDocumentsSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        DocumentSlot(
          label: isCar
              ? AppStrings.wizardDocRegistrationCar
              : AppStrings.wizardDocRegistrationMoto,
          file: registrationCard,
          onTap: onPickRegistration,
        ),
        const SizedBox(height: 18),
        DocumentSlot(
          label: AppStrings.wizardDocLicense,
          file: license,
          onTap: onPickLicense,
        ),
      ],
    );
  }
}

class DocumentSlot extends StatelessWidget {
  const DocumentSlot({
    super.key,
    required this.label,
    required this.file,
    required this.onTap,
  });

  final String label;
  final File? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
          if (file != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                file!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
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
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ],
      ),
    );
  }
}
