import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../services/driver_tracking_service.dart';
import 'recharge_screen.dart';

const _pointeNoireCenter = LatLng(-4.7889, 11.8656);

/// Aperçu du tableau de bord chauffeur (double carte de solde + carte en
/// direct), reproduit à l'identique de la maquette envoyée. Écran
/// SUPPLÉMENTAIRE pour l'instant : il ne remplace pas [DriverHomeScreen] et
/// ne touche pas à sa logique de demandes de course / course active — son
/// intégration au flux réel sera décidée plus tard, pendant les tests.
///
/// Le solde affiché dans les deux cartes est le même solde chauffeur unique
/// qu'ailleurs dans l'app (`driver_profiles/{uid}/wallet/current`) : les
/// libellés "Compte Recharge" / "Compte Chauffeur" sont purement visuels,
/// il n'y a pas de nouvelle logique de wallet à deux comptes.
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key, required this.driverName});

  final String driverName;

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final _trackingService = DriverTrackingService();
  final _mapController = MapController();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _trackingService.stopTracking();
    super.dispose();
  }

  void _toggleOnline(bool value, {required bool hasBalance}) {
    final uid = _uid;
    if (uid == null || !hasBalance) return;
    FirebaseFirestore.instance.collection('users').doc(uid).update({'driverOnline': value});
    if (value) {
      _trackingService.startTracking();
    } else {
      _trackingService.stopTracking();
    }
  }

  void _comingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.socialAuthComingSoon)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: uid == null
              ? null
              : FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, userSnap) {
            final online = userSnap.data?.data()?['driverOnline'] as bool? ?? false;
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: uid == null
                  ? null
                  : FirebaseFirestore.instance
                      .collection('driver_profiles')
                      .doc(uid)
                      .collection('wallet')
                      .doc('current')
                      .snapshots(),
              builder: (context, walletSnap) {
                final balance = walletSnap.data?.data()?['balance'] as int? ?? 0;
                final hasBalance = balance > 0;
                return Column(
                  children: [
                    _Header(driverName: widget.driverName, online: online),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _RechargeAccountCard(
                                balance: balance,
                                onRecharge: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const RechargeScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _EarningsAccountCard(balance: balance, onSeeEarnings: _comingSoon),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: const MapOptions(initialCenter: _pointeNoireCenter, initialZoom: 13),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.yame.yame',
                          ),
                          if (uid != null)
                            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('driver_profiles')
                                  .doc(uid)
                                  .collection('location')
                                  .doc('current')
                                  .snapshots(),
                              builder: (context, locSnap) {
                                final data = locSnap.data?.data();
                                if (data == null || data['lat'] == null || data['lng'] == null) {
                                  return const SizedBox.shrink();
                                }
                                final pos = LatLng(
                                  (data['lat'] as num).toDouble(),
                                  (data['lng'] as num).toDouble(),
                                );
                                return MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: pos,
                                      width: 44,
                                      height: 44,
                                      child: const Icon(
                                        Icons.directions_car_rounded,
                                        color: AppColors.accent,
                                        size: 32,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: _MapControls(mapController: _mapController),
                          ),
                        ],
                      ),
                    ),
                    _WaitingForRequestsBar(
                      online: online,
                      hasBalance: hasBalance,
                      onChanged: (value) => _toggleOnline(value, hasBalance: hasBalance),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.driverName, required this.online});

  final String driverName;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pin_drop_rounded, color: AppColors.accent, size: 22),
              const SizedBox(width: 6),
              Text(
                'YAME',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppColors.accent, letterSpacing: 0.5),
              ),
              const Spacer(),
              const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.accent,
                child: Text(
                  driverName.isNotEmpty ? driverName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.background,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppStrings.homeGreeting} $driverName',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      AppStrings.driverDashboardTitle,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (online ? AppColors.success : AppColors.textDisabled).withValues(
                          alpha: 0.16,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: online ? AppColors.success : AppColors.textDisabled,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            online ? AppStrings.driverOnline : AppStrings.driverOffline,
                            style: TextStyle(
                              color: online ? AppColors.success : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RechargeAccountCard extends StatelessWidget {
  const _RechargeAccountCard({required this.balance, required this.onRecharge});

  final int balance;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
            child: const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.driverDashboardRechargeAccount,
            style: const TextStyle(color: AppColors.background, fontWeight: FontWeight.w700),
          ),
          Text(
            AppStrings.driverDashboardRechargeAccountSubtitle,
            style: TextStyle(color: AppColors.background.withValues(alpha: 0.7), fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            '$balance FCFA',
            style: const TextStyle(
              color: AppColors.background,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.background.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                AppStrings.driverDashboardRechargeNonWithdrawable,
                style: TextStyle(color: AppColors.background.withValues(alpha: 0.7), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.accent,
              ),
              onPressed: onRecharge,
              child: Text(AppStrings.driverDashboardRecharge),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsAccountCard extends StatelessWidget {
  const _EarningsAccountCard({required this.balance, required this.onSeeEarnings});

  final int balance;
  final VoidCallback onSeeEarnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.success, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.driverDashboardEarningsAccount,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
          Text(
            AppStrings.driverDashboardEarningsAccountSubtitle,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            '$balance FCFA',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSeeEarnings,
              child: Text(AppStrings.driverDashboardSeeEarnings),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({required this.mapController});

  final MapController mapController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MapControlButton(
          icon: Icons.my_location_rounded,
          onTap: () => mapController.move(_pointeNoireCenter, mapController.camera.zoom),
        ),
        const SizedBox(height: 8),
        _MapControlButton(
          icon: Icons.add_rounded,
          onTap: () => mapController.move(mapController.camera.center, mapController.camera.zoom + 1),
        ),
        const SizedBox(height: 8),
        _MapControlButton(
          icon: Icons.remove_rounded,
          onTap: () => mapController.move(mapController.camera.center, mapController.camera.zoom - 1),
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}

class _WaitingForRequestsBar extends StatelessWidget {
  const _WaitingForRequestsBar({
    required this.online,
    required this.hasBalance,
    required this.onChanged,
  });

  final bool online;
  final bool hasBalance;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.watch_later_outlined, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.driverDashboardWaitingTitle,
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.driverDashboardWaitingSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Switch(
            value: online,
            activeThumbColor: AppColors.accent,
            onChanged: hasBalance ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
