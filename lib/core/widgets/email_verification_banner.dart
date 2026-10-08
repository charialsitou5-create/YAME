import 'package:flutter/material.dart';

import '../../services/email_verification_service.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';

/// Bandeau discret non bloquant pour les comptes e-mail non vérifiés.
/// Se masque seul une fois l'adresse vérifiée.
class EmailVerificationBanner extends StatefulWidget {
  const EmailVerificationBanner({super.key, this.source, this.onVisibilityChanged});

  final EmailVerificationSource? source;

  /// Notifié quand le bandeau se masque (adresse vérifiée).
  final ValueChanged<bool>? onVisibilityChanged;

  /// `true` si le bandeau doit être affiché pour [source].
  static bool visibleFor(EmailVerificationSource source) => source.needsVerification;

  @override
  State<EmailVerificationBanner> createState() => _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner> {
  late final EmailVerificationSource _source =
      widget.source ?? FirebaseEmailVerificationSource();
  late bool _visible = _source.needsVerification;
  bool _busy = false;

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await _source.resend();
      _toast(AppStrings.emailVerifyResent);
    } catch (_) {
      _toast(AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      final verified = await _source.reloadAndCheck();
      if (!mounted) return;
      if (verified) {
        setState(() => _visible = false);
        widget.onVisibilityChanged?.call(false);
        _toast(AppStrings.emailVerifyVerified);
      } else {
        _toast(AppStrings.emailVerifyStillPending);
      }
    } catch (_) {
      _toast(AppStrings.errorNetwork);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Material(
      color: AppColors.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 20, color: AppColors.accentBright),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                AppStrings.emailVerifyBannerTitle,
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _resend,
              child: const Text(AppStrings.emailVerifyResend),
            ),
            TextButton(
              onPressed: _busy ? null : _check,
              child: const Text(AppStrings.emailVerifyDone),
            ),
          ],
        ),
      ),
    );
  }
}
