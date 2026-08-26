import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Recharge du solde chauffeur (espèces au guichet, mobile money, virement).
/// Les moyens de paiement ne sont pas encore branchés à un opérateur.
class RechargeScreen extends StatelessWidget {
  const RechargeScreen({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.socialAuthComingSoon)));
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
                          : FirebaseFirestore.instance.collection('driver_profiles').doc(uid).snapshots(),
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
                onTap: () => _showComingSoon(context),
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
