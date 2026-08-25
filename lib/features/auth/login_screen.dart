import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../routes/app_routes.dart';

/// Connexion par e-mail + mot de passe.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _messageForAuthError(e));
    } catch (_) {
      setState(() => _errorMessage = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _messageForAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-credential':
        return AppStrings.errorUserNotFound;
      case 'wrong-password':
        return AppStrings.errorWrongPassword;
      case 'invalid-email':
        return AppStrings.errorEmailInvalid;
      case 'network-request-failed':
        return AppStrings.errorNetwork;
      default:
        return AppStrings.errorGeneric;
    }
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
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: AppStrings.fieldEmail),
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
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
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
