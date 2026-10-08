import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/vehicle_type.dart';
import '../../repositories/wallet_repository.dart';
import '../../services/driver_tracking_service.dart';
import '../../services/routing_service.dart';
import 'driver_home/account_cards.dart';
import 'driver_home/driver_header.dart';
import 'driver_home/driver_home_controller.dart';
import 'driver_home/driver_map_panel.dart';
import 'driver_home/active_ride_panel.dart';
import 'driver_home/ride_offer_card.dart';
import 'driver_home/status_notices.dart';
import 'recharge_screen.dart';

/// Écran chauffeur : bascule en ligne/hors ligne, carte live, solde, liste
/// des demandes de course ouvertes pour son type de véhicule, et suivi de
/// la course acceptée.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({
    super.key,
    required this.vehicleType,
    required this.driverName,
    @visibleForTesting this.firestore,
    @visibleForTesting this.uid,
    @visibleForTesting this.trackingService,
    @visibleForTesting this.routeFetcher,
  });

  final VehicleType vehicleType;
  final String driverName;

  /// Surcharges pour les tests ; par défaut, les vrais services Firebase.
  final FirebaseFirestore? firestore;
  final String? uid;
  final DriverTrackingService? trackingService;

  /// Surcharge de [RoutingService.fetchRoute] pour les tests — sans elle,
  /// un test avec une course active déclencherait un vrai appel réseau vers
  /// le serveur OSRM public à chaque rendu de la carte.
  final Future<RouteResult?> Function({
    required LatLng from,
    required LatLng to,
  })?
  routeFetcher;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  late final DriverHomeController _c;
  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;
  String? get _uid =>
      widget.uid ??
      (widget.firestore != null
          ? null
          : FirebaseAuth.instance.currentUser?.uid);
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _c = DriverHomeController(
      db: _db,
      uid: _uid,
      trackingService: widget.trackingService ?? DriverTrackingService(),
      routeFetcher: widget.routeFetcher,
      onMessage: (m) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(m)));
      },
      onMoveMap: (p, zoom) => _mapController.move(p, zoom),
    )..addListener(_onChanged);
    _c.init();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: uid == null ? null : WalletRepository(_db).watchWallet(uid),
          builder: (context, snapshot) {
            // Avant la première valeur du stream, `snapshot.data` est
            // `null` et `balance` retomberait à 0 — indiscernable d'un
            // solde réellement épuisé, ce qui déclenchait le garde-fou
            // ci-dessous à tort dès l'ouverture de l'écran (bug trouvé
            // pendant les tests manuels du dispatch, 2026-09-15).
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              );
            }
            final balance = snapshot.data?.data()?['balance'] as int? ?? 0;
            final earningsBalance =
                snapshot.data?.data()?['earningsBalance'] as int? ?? 0;
            final hasBalance = balance > 0;

            if (_c.online && !hasBalance && _c.activeRideId == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _c.toggleOnline(false);
              });
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      DriverHeader(
                        driverName: widget.driverName,
                        online: _c.online,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: RechargeAccountCard(
                          balance: balance,
                          onRecharge: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RechargeScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: EarningsAccountCard(
                          balance: earningsBalance,
                          onSeeEarnings: () => ScaffoldMessenger.of(context)
                              .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    AppStrings.socialAuthComingSoon,
                                  ),
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      WaitingForRequestsBar(
                        online: _c.online,
                        canToggle: hasBalance && _c.activeRideId == null,
                        onChanged: (value) => _c.toggleOnline(value),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: _c.activeRideId != null
                      ? ActiveRide(
                          rideId: _c.activeRideId!,
                          onEnd: _c.endRide,
                          onAdvance: _c.advanceRide,
                          onClientCancelled: _c.releaseCancelledRide,
                          onUnavailable: _c.clearActiveRide,
                          firestore: _db,
                          eta: _c.route?.duration,
                        )
                      : !hasBalance
                      ? const BalanceRequiredNotice()
                      : !_c.online
                      ? const OfflineNotice()
                      : RideOfferCard(
                          onRespond: _c.respondToOffer,
                          firestore: _db,
                          uid: _uid,
                        ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      DriverMapPanel(
                        mapController: _mapController,
                        firestore: _db,
                        uid: uid,
                        activeRideId: _c.activeRideId,
                        route: _c.route,
                        onNeedRoute: _c.maybeFetchRoute,
                        onRecenter: _c.recenterOnMe,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
