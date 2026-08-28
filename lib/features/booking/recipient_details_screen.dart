import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Détails de la personne pour qui la course est commandée.
typedef RideRecipient = ({
  String name,
  String phone,
  String? instructions,
  bool contactRequesterInstead,
});

/// Formulaire "Commander pour quelqu'un d'autre" — écran clair, comme le
/// paiement et la notation, distinct du thème sombre du reste de l'app.
class RecipientDetailsScreen extends StatefulWidget {
  const RecipientDetailsScreen({super.key, this.initial});

  final RideRecipient? initial;

  @override
  State<RecipientDetailsScreen> createState() => _RecipientDetailsScreenState();
}

class _RecipientDetailsScreenState extends State<RecipientDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.initial?.name);
  late final _phoneController = TextEditingController(text: widget.initial?.phone);
  late final _instructionsController = TextEditingController(text: widget.initial?.instructions);
  late bool _contactRequesterInstead = widget.initial?.contactRequesterInstead ?? false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    final instructions = _instructionsController.text.trim();
    Navigator.of(context).pop<RideRecipient>((
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      instructions: instructions.isEmpty ? null : instructions,
      contactRequesterInstead: _contactRequesterInstead,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        title: const Text(
          AppStrings.orderForSomeoneTitle,
          style: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.lightBorder),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppStrings.orderForSomeoneSectionTitle,
                  style: TextStyle(
                    color: AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                _FieldLabel(AppStrings.fieldName),
                const SizedBox(height: 8),
                _LightTextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? AppStrings.errorRequired : null,
                ),
                const SizedBox(height: 20),
                _FieldLabel(AppStrings.fieldPhone),
                const SizedBox(height: 8),
                _LightTextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return AppStrings.errorRequired;
                    if (value.trim().length < 8) return AppStrings.errorPhoneInvalid;
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _FieldLabel(AppStrings.orderForSomeoneInstructions),
                const SizedBox(height: 8),
                _LightTextField(
                  controller: _instructionsController,
                  hintText: AppStrings.orderForSomeoneInstructionsHint,
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _contactRequesterInstead = !_contactRequesterInstead),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.orderForSomeoneContactToggle,
                          style: const TextStyle(
                            color: AppColors.lightTextPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        value: _contactRequesterInstead,
                        activeTrackColor: AppColors.accent,
                        onChanged: (value) => setState(() => _contactRequesterInstead = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.background,
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text(
                      AppStrings.orderForSomeoneConfirm,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
    );
  }
}

class _LightTextField extends StatelessWidget {
  const _LightTextField({
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: AppColors.lightTextPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.lightTextSecondary),
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}
