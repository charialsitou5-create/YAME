import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/fare.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ride_request.dart';

enum _PaymentMethod { card, mobileMoney }

/// Paiement de la course — écran clair, comme la notation, distinct du
/// thème sombre du reste de l'application.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.ride});

  final RideRequest ride;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _driverIdController = TextEditingController();
  _PaymentMethod _method = _PaymentMethod.card;
  bool _submitting = false;
  String? _error;

  late final int _amount = estimateFareFcfa(
    pickup: widget.ride.pickup,
    destination: widget.ride.destination,
    vehicleType: widget.ride.vehicleType,
  );

  @override
  void dispose() {
    _driverIdController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_driverIdController.text.trim().isEmpty) {
      setState(() => _error = AppStrings.paymentErrorDriverIdRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await FirebaseFirestore.instance.collection('ride_requests').doc(widget.ride.id).update({
        'paymentStatus': 'paid',
        'paymentMethod': _method == _PaymentMethod.card ? 'card' : 'mobile_money',
        'paymentAmount': _amount,
        'paymentDriverId': _driverIdController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.paymentSuccess)));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppStrings.paymentError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
          AppStrings.paymentTitle,
          style: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(false),
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
              Text(
                AppStrings.paymentAmountLabel,
                style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                '${formatFcfa(_amount)} FCFA',
                style: const TextStyle(
                  color: AppColors.lightTextPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightBorder),
                ),
                child: Column(
                  children: [
                    _MethodRow(
                      icon: Icons.credit_card_rounded,
                      label: AppStrings.paymentMethodCard,
                      selected: _method == _PaymentMethod.card,
                      onTap: () => setState(() => _method = _PaymentMethod.card),
                    ),
                    const Divider(height: 1, color: AppColors.lightBorder),
                    _MethodRow(
                      icon: Icons.smartphone_rounded,
                      label: AppStrings.paymentMethodMobileMoney,
                      selected: _method == _PaymentMethod.mobileMoney,
                      onTap: () => setState(() => _method = _PaymentMethod.mobileMoney),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppStrings.paymentSecurityNotice,
                        style: const TextStyle(color: AppColors.lightTextPrimary, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                AppStrings.paymentDriverIdLabel,
                style: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _driverIdController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: AppColors.lightTextPrimary),
                decoration: InputDecoration(
                  hintText: AppStrings.paymentDriverIdHint,
                  hintStyle: const TextStyle(color: AppColors.lightTextSecondary),
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
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.lightTextSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppStrings.paymentDriverIdInfo,
                      style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.background,
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                        )
                      : Text(
                          'Payer ${formatFcfa(_amount)} FCFA',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.lightTextPrimary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? AppColors.accent : AppColors.lightTextSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
