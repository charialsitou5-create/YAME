import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Raison choisie par le client pour annuler sa course.
typedef CancelReason = ({String reason, String? comment});

/// Formulaire "Pourquoi la course a été annulée ?" — écran clair, comme le
/// paiement et la notation, distinct du thème sombre du reste de l'app.
class CancelReasonScreen extends StatefulWidget {
  const CancelReasonScreen({super.key});

  @override
  State<CancelReasonScreen> createState() => _CancelReasonScreenState();
}

class _CancelReasonScreenState extends State<CancelReasonScreen> {
  static const _reasons = [
    AppStrings.cancelReasonDriverFar,
    AppStrings.cancelReasonWaitTooLong,
    AppStrings.cancelReasonPlansChanged,
    AppStrings.cancelReasonPaymentIssue,
    AppStrings.cancelReasonDriverIssue,
    AppStrings.cancelReasonOther,
  ];

  final _commentController = TextEditingController();
  String? _selectedReason;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _selectedReason;
    if (reason == null) {
      setState(() => _error = AppStrings.cancelReasonErrorRequired);
      return;
    }
    final comment = _commentController.text.trim();
    Navigator.of(context).pop<CancelReason>((
      reason: reason,
      comment: comment.isEmpty ? null : comment,
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
          AppStrings.cancelReasonTitle,
          style: TextStyle(
            color: AppColors.lightTextPrimary,
            fontWeight: FontWeight.w700,
          ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppStrings.cancelReasonQuestion,
                style: TextStyle(
                  color: AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _selectedReason,
                onChanged: (value) => setState(() {
                  _selectedReason = value;
                  _error = null;
                }),
                child: Column(
                  children: _reasons
                      .map(
                        (reason) => RadioListTile<String>(
                          value: reason,
                          activeColor: AppColors.accent,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            reason,
                            style: const TextStyle(
                              color: AppColors.lightTextPrimary,
                              fontSize: 15.5,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 16),
              const Text(
                AppStrings.cancelReasonCommentLabel,
                style: TextStyle(
                  color: AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _commentController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.lightTextPrimary),
                decoration: InputDecoration(
                  hintText: AppStrings.cancelReasonCommentHint,
                  hintStyle: const TextStyle(
                    color: AppColors.lightTextSecondary,
                  ),
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
                ),
              ),
              const SizedBox(height: 28),
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
                    AppStrings.cancelReasonConfirm,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
