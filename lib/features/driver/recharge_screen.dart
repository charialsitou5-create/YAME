import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../services/recharge_service.dart';

/// Recharge du solde chauffeur (espèces au guichet, mobile money, virement).
/// Seul Mobile Money (MTN/Airtel) est branché à un opérateur pour l'instant.
class RechargeScreen extends StatelessWidget {
  const RechargeScreen({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.socialAuthComingSoon)));
  }

  Future<void> _openMobileMoneySheet(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    String? initialPhone;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      initialPhone = doc.data()?['phone'] as String?;
    }
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MobileMoneySheet(initialPhone: initialPhone),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(AppStrings.rechargeTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.rechargeCurrentBalance,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: uid == null
                          ? null
                          : FirebaseFirestore.instance
                              .collection('driver_profiles')
                              .doc(uid)
                              .collection('wallet')
                              .doc('current')
                              .snapshots(),
                      builder: (context, snapshot) {
                        final balance = snapshot.data?.data()?['balance'] as int? ?? 0;
                        return Text(
                          '$balance FCFA',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 30),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(AppStrings.rechargeChooseMethod, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              _MethodTile(
                icon: Icons.payments_outlined,
                label: AppStrings.rechargeCash,
                onTap: () => _showComingSoon(context),
              ),
              const SizedBox(height: 12),
              _MethodTile(
                icon: Icons.smartphone_rounded,
                label: AppStrings.rechargeMobileMoney,
                onTap: () => _openMobileMoneySheet(context),
              ),
              const SizedBox(height: 12),
              _MethodTile(
                icon: Icons.account_balance_outlined,
                label: AppStrings.rechargeBankTransfer,
                onTap: () => _showComingSoon(context),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔔', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppStrings.rechargeNotice,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileMoneySheet extends StatefulWidget {
  const _MobileMoneySheet({this.initialPhone});

  final String? initialPhone;

  @override
  State<_MobileMoneySheet> createState() => _MobileMoneySheetState();
}

class _MobileMoneySheetState extends State<_MobileMoneySheet> {
  final _formKey = GlobalKey<FormState>();
  late final _phoneController = TextEditingController(text: widget.initialPhone ?? '');
  final _amountController = TextEditingController();

  MobileMoneyProvider _provider = MobileMoneyProvider.mtn;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await RechargeService.initiate(
        amount: num.parse(_amountController.text.trim()),
        phoneNumber: _phoneController.text.trim(),
        provider: _provider,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.rechargeInitiated)));
    } on RechargeException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = AppStrings.rechargeInitiateError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.rechargeChooseProvider, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ProviderChip(
                    label: AppStrings.rechargeProviderMtn,
                    selected: _provider == MobileMoneyProvider.mtn,
                    onTap: () => setState(() => _provider = MobileMoneyProvider.mtn),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ProviderChip(
                    label: AppStrings.rechargeProviderAirtel,
                    selected: _provider == MobileMoneyProvider.airtel,
                    onTap: () => setState(() => _provider = MobileMoneyProvider.airtel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: AppStrings.rechargeAmountLabel,
                hintText: AppStrings.rechargeAmountHint,
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (value) {
                final amount = num.tryParse(value?.trim() ?? '');
                if (amount == null || amount <= 0) return AppStrings.rechargeAmountRequired;
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: AppStrings.rechargePhoneLabel,
                prefixIcon: Icon(Icons.call_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return AppStrings.errorRequired;
                if (value.trim().length < 8) return AppStrings.errorPhoneInvalid;
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(AppStrings.rechargeConfirm),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.label, required this.selected, required this.onTap});

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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
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

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textPrimary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
