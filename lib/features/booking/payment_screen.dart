import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/fare.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ride_request.dart';
import '../../services/payment_service.dart';

/// Paiement de la course — écran clair, comme la notation, distinct du
/// thème sombre du reste de l'application.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.ride});

  final RideRequest ride;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  RidePaymentMethod _method = RidePaymentMethod.card;
  bool _submitting = false;
  String? _error;

  // Tant que la grille tarifaire n'est pas chargée (au plus 5 s), le bouton de
  // paiement reste inactif : on ne facture jamais un montant provisoire.
  // Sans effet si `widget.ride.price` est déjà connu (voir `_amount`).
  FarePricing? _pricing;

  /// Affiche le prix déjà annoncé au client à la commande (`ride.price`,
  /// voir `booking_screen.dart`) plutôt que de le recalculer ici — sinon un
  /// changement de grille tarifaire (`app_config/pricing`) pendant la course
  /// ferait apparaître un montant différent de celui vu en commandant.
  /// `null` seulement pour une course créée avant l'introduction de ce champ.
  /// Dans tous les cas, ce n'est qu'un affichage : le montant réellement
  /// facturé est toujours recalculé côté serveur par `yame-admin`.
  int get _amount =>
      widget.ride.price ??
      estimateFareFcfa(
        pickup: widget.ride.pickup,
        destination: widget.ride.destination,
        vehicleType: widget.ride.vehicleType,
        pricing: _pricing ?? FarePricing.defaults,
      );

  @override
  void initState() {
    super.initState();
    if (widget.ride.price == null) {
      loadFarePricing().then((p) {
        if (mounted) setState(() => _pricing = p);
      });
    }
  }

  Future<void> _pay() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await PaymentService.pay(rideId: widget.ride.id!, method: _method);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.paymentSuccess)));
      Navigator.of(context).pop(true);
    } on RidePaymentException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
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
                      selected: _method == RidePaymentMethod.card,
                      onTap: () => setState(() => _method = RidePaymentMethod.card),
                    ),
                    const Divider(height: 1, color: AppColors.lightBorder),
                    _MethodRow(
                      icon: Icons.smartphone_rounded,
                      label: AppStrings.paymentMethodMobileMoney,
                      selected: _method == RidePaymentMethod.mobileMoney,
                      onTap: () => setState(() => _method = RidePaymentMethod.mobileMoney),
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
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_submitting || (widget.ride.price == null && _pricing == null))
                          ? null
                          : _pay,
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
