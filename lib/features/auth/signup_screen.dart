import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../routes/app_routes.dart';

/// Inscription : nom, téléphone, e-mail, mot de passe.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
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
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final uid = credential.user!.uid;
      final user = AppUser(
        uid: uid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        role: widget.role,
      );
      await FirebaseFirestore.instance.collection('users').doc(uid).set(user.toMap());

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
      case 'email-already-in-use':
        return AppStrings.errorEmailInUse;
      case 'invalid-email':
        return AppStrings.errorEmailInvalid;
      case 'weak-password':
        return AppStrings.errorPasswordTooShort;
      case 'network-request-failed':
        return AppStrings.errorNetwork;
      default:
        return AppStrings.errorGeneric;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.signupTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chip(label: Text(widget.role.label)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: AppStrings.fieldName),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? AppStrings.errorRequired : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: AppStrings.fieldPhone),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return AppStrings.errorRequired;
                    if (value.trim().length < 8) return AppStrings.errorPhoneInvalid;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: AppStrings.fieldEmail),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return AppStrings.errorRequired;
                    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
                    return valid ? null : AppStrings.errorEmailInvalid;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: AppStrings.fieldPassword),
                  validator: (value) {
                    if (value == null || value.isEmpty) return AppStrings.errorRequired;
                    if (value.length < 6) return AppStrings.errorPasswordTooShort;
                    return null;
                  },
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
                      : const Text(AppStrings.signupCta),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed(AppRoutes.login),
                    child: const Text(AppStrings.signupHasAccount),
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
