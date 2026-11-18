import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/fare.dart';

/// Les deux comptes du chauffeur, côte à côte et de même hauteur
/// (maquette du 2026-10-21) : Recharge (crème/jaune) à gauche,
/// Chauffeur (menthe/vert) à droite.
class DriverAccountCards extends StatelessWidget {
  const DriverAccountCards({
    super.key,
    required this.rechargeBalance,
    required this.earningsBalance,
    required this.onRecharge,
    required this.onSeeEarnings,
  });

  final int rechargeBalance;
  final int earningsBalance;
  final VoidCallback onRecharge;
  final VoidCallback onSeeEarnings;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _AccountCard(
              background: _AccountPalette.rechargeBackground,
              accent: _AccountPalette.rechargeAccent,
              buttonText: _AccountPalette.ink,
              icon: Icons.bolt_rounded,
              title: AppStrings.driverDashboardRechargeAccount,
              subtitle: AppStrings.driverDashboardRechargeAccountSubtitle,
              balance: rechargeBalance,
              footnote: AppStrings.driverDashboardRechargeNonWithdrawable,
              actionLabel: AppStrings.driverDashboardRecharge,
              onAction: onRecharge,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _AccountCard(
              background: _AccountPalette.earningsBackground,
              accent: _AccountPalette.earningsAccent,
              buttonText: Colors.white,
              icon: Icons.account_balance_wallet_outlined,
              title: AppStrings.driverDashboardEarningsAccount,
              subtitle: AppStrings.driverDashboardEarningsAccountSubtitle,
              balance: earningsBalance,
              actionLabel: AppStrings.driverDashboardSeeEarnings,
              onAction: onSeeEarnings,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountPalette {
  _AccountPalette._();

  static const ink = Color(0xFF17171C);
  static const inkSoft = Color(0xFF5E5E68);
  static const rechargeBackground = Color(0xFFFFF7DD);
  static const rechargeAccent = Color(0xFFFFCC1A);
  static const earningsBackground = Color(0xFFE2F6EE);
  static const earningsAccent = Color(0xFF16A36A);
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.background,
    required this.accent,
    required this.buttonText,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.balance,
    required this.actionLabel,
    required this.onAction,
    this.footnote,
  });

  final Color background;
  final Color accent;
  final Color buttonText;
  final IconData icon;
  final String title;
  final String subtitle;
  final int balance;
  final String? footnote;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: buttonText, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: _AccountPalette.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: _AccountPalette.inkSoft,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatFcfa(balance),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const TextSpan(
                    text: ' FCFA',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              style: const TextStyle(color: _AccountPalette.ink),
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: _AccountPalette.inkSoft,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    footnote!,
                    style: const TextStyle(
                      color: _AccountPalette.inkSoft,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: buttonText,
                elevation: 0,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                // Sans famille explicite, le texte d'un bouton retombe sur
                // la police système (Roboto) au lieu de Poppins.
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: onAction,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(actionLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
