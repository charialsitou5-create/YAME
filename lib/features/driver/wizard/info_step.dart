import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

class InfoStep extends StatelessWidget {
  const InfoStep({
    super.key,
    required this.isCar,
    required this.formKey,
    required this.modelController,
    required this.yearController,
    required this.colorController,
    required this.plateController,
    required this.seats,
    required this.onSeatsChanged,
  });

  final bool isCar;
  final GlobalKey<FormState> formKey;
  final TextEditingController modelController;
  final TextEditingController yearController;
  final TextEditingController colorController;
  final TextEditingController plateController;
  final int? seats;
  final ValueChanged<int?> onSeatsChanged;

  @override
  Widget build(BuildContext context) {
    final seatOptions = isCar ? const [2, 4, 5, 7] : const [1, 2];

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: isCar ? 'Informations ' : 'Informations '),
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
                ? AppStrings.wizardVehicleInfoSubtitle
                : AppStrings.wizardMotoInfoSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FieldLabel(
            isCar
                ? AppStrings.wizardFieldModelCar
                : AppStrings.wizardFieldModelMoto,
          ),
          TextFormField(
            controller: modelController,
            decoration: InputDecoration(
              hintText: isCar
                  ? AppStrings.wizardFieldModelCarHint
                  : AppStrings.wizardFieldModelMotoHint,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? AppStrings.wizardErrorRequired
                : null,
          ),
          const SizedBox(height: 18),
          FieldLabel(AppStrings.wizardFieldYear),
          TextFormField(
            controller: yearController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: AppStrings.wizardFieldYearHint,
              suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
            ),
            validator: (v) {
              final year = int.tryParse(v?.trim() ?? '');
              final currentYear = DateTime.now().year;
              if (year == null || year < 1990 || year > currentYear + 1) {
                return AppStrings.wizardErrorYearInvalid;
              }
              return null;
            },
          ),
          if (isCar) ...[
            const SizedBox(height: 18),
            const FieldLabel(AppStrings.wizardFieldColor),
            TextFormField(
              controller: colorController,
              decoration: const InputDecoration(
                hintText: AppStrings.wizardFieldColorHint,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? AppStrings.wizardErrorRequired
                  : null,
            ),
          ],
          const SizedBox(height: 18),
          const FieldLabel(AppStrings.wizardFieldPlateCar),
          TextFormField(
            controller: plateController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: isCar
                  ? AppStrings.wizardFieldPlateCarHint
                  : AppStrings.wizardFieldPlateMotoHint,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? AppStrings.wizardErrorRequired
                : null,
          ),
          const SizedBox(height: 18),
          const FieldLabel(AppStrings.wizardFieldSeats),
          DropdownButtonFormField<int>(
            initialValue: seats,
            hint: Text(
              isCar
                  ? AppStrings.wizardFieldSeatsHint
                  : AppStrings.wizardFieldSeatsMotoHint,
            ),
            items: seatOptions
                .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                .toList(growable: false),
            onChanged: onSeatsChanged,
            validator: (v) => v == null ? AppStrings.wizardErrorRequired : null,
          ),
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
