import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

enum _ReportKind { incident, feedback }

const _categories = [
  (AppStrings.reportCategorySecurity, 'securite'),
  (AppStrings.reportCategoryPayment, 'paiement'),
  (AppStrings.reportCategoryBehavior, 'comportement'),
  (AppStrings.reportCategoryVehicle, 'vehicule'),
  (AppStrings.reportCategoryOther, 'autre'),
];

/// Écran partagé client/chauffeur pour signaler un incident ou laisser un
/// avis — visible côté admin dans le panneau de gestion.
class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key, this.rideId});

  final String? rideId;

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  _ReportKind _kind = _ReportKind.incident;
  String _category = _categories.first.$2;
  final _messageController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_messageController.text.trim().isEmpty) {
      setState(() => _error = AppStrings.reportErrorRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('not signed in');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();

      await FirebaseFirestore.instance.collection('incidents').add({
        'kind': _kind.name,
        'category': _category,
        'message': _messageController.text.trim(),
        'reporterUid': user.uid,
        'reporterName': userData?['name'] as String? ?? '',
        'reporterRole': userData?['role'] as String? ?? '',
        if (widget.rideId != null) 'rideId': widget.rideId,
        'status': 'open',
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.reportSuccess)));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppStrings.reportError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(AppStrings.reportTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _KindChip(
                      label: AppStrings.reportKindIncident,
                      selected: _kind == _ReportKind.incident,
                      onTap: () => setState(() => _kind = _ReportKind.incident),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _KindChip(
                      label: AppStrings.reportKindFeedback,
                      selected: _kind == _ReportKind.feedback,
                      onTap: () => setState(() => _kind = _ReportKind.feedback),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.reportCategoryLabel,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories
                    .map(
                      (c) => ChoiceChip(
                        label: Text(c.$1),
                        selected: _category == c.$2,
                        onSelected: (_) => setState(() => _category = c.$2),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.reportMessageLabel,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _messageController,
                maxLines: 5,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: AppStrings.reportMessageHint,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 28),
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
                      : const Text(AppStrings.reportSubmit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.background : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
