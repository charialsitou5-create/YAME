import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../routes/app_routes.dart';

/// Connexion par téléphone/e-mail + mot de passe.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    // TODO(yame): remplacer par un vrai appel Firebase Auth
    // (signInWithEmailAndPassword ou connexion par téléphone) puis charger
    // le profil AppUser depuis Firestore `users/{uid}`.
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.loginTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _identifierController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: AppStrings.fieldPhone),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? AppStrings.errorRequired : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: AppStrings.fieldPassword),
                  validator: (value) =>
                      (value == null || value.isEmpty) ? AppStrings.errorRequired : null,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(AppStrings.loginCta),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushReplacementNamed(AppRoutes.roleSelection),
                    child: const Text(AppStrings.loginNoAccount),
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
