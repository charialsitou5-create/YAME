import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

typedef PasswordResetSender = Future<void> Function(String email);

Future<void> _defaultSender(String email) =>
    FirebaseAuth.instance.sendPasswordResetEmail(email: email);

/// Message d'erreur de réinitialisation. `user-not-found` renvoie `null` :
/// le succès affiché ne doit pas révéler si le compte existe.
String? passwordResetErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
      return null;
    case 'invalid-email':
      return AppStrings.errorEmailInvalid;
    case 'too-many-requests':
      return AppStrings.forgotPasswordTooManyRequests;
    case 'network-request-failed':
      return AppStrings.errorNetwork;
    default:
      return AppStrings.errorGeneric;
  }
}

/// Envoi d'un e-mail de réinitialisation du mot de passe.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
    this.sender = _defaultSender,
  });

  final String initialEmail;
  final PasswordResetSender sender;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.initialEmail);
  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.sender(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      final message = passwordResetErrorMessage(e);
      if (!mounted) return;
      setState(() {
        if (message == null) {
          _sent = true;
        } else {
          _error = message;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.forgotPasswordTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _sent ? _buildSuccess(context) : _buildForm(context),
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.accentBright),
        const SizedBox(height: 16),
        Text(AppStrings.forgotPasswordSuccess, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text(AppStrings.forgotPasswordBackToLogin),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.forgotPasswordSubtitle, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              hintText: AppStrings.fieldEmail,
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? AppStrings.errorRequired : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(AppStrings.forgotPasswordCta),
            ),
          ),
        ],
      ),
    );
  }
}
