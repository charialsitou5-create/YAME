import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../routes/app_routes.dart';

/// Réclame le numéro de téléphone après une première connexion
/// Google/Facebook — ni l'un ni l'autre ne le communique, alors qu'il est
/// indispensable au reste de l'app (contact chauffeur/passager, SMS).
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'phone': _phoneController.text.trim(),
      });

      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
    } catch (_) {
      setState(() => _errorMessage = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.completeProfileTitle,
                      style: Theme.of(context).textTheme.displayLarge
                          ?.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppStrings.completeProfileSubtitle,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _phoneController,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: AppStrings.fieldPhone,
                        prefixIcon: Icon(Icons.call_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return AppStrings.errorRequired;
                        if (value.trim().length < 8)
                          return AppStrings.errorPhoneInvalid;
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(AppStrings.completeProfileCta),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
