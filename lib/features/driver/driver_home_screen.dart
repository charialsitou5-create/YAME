import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ride_request.dart';
import '../../models/vehicle_type.dart';
import '../../repositories/ride_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/wallet_repository.dart';
import '../../services/payment_service.dart';
import '../../services/dispatch_response_service.dart';
import '../../services/driver_tracking_service.dart';
import '../../services/email_verification_service.dart';
import '../../services/routing_service.dart';
import 'driver_home/account_cards.dart';
import 'driver_home/driver_header.dart';
import 'driver_home/driver_map_panel.dart';
import 'driver_home/active_ride_panel.dart';
import 'driver_home/ride_offer_card.dart';
import 'driver_home/status_notices.dart';
import 'recharge_screen.dart';
import '../../services/error_reporter.dart';

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
  bool _online = false;
  String? _activeRideId;
  late final DriverTrackingService _trackingService =
      widget.trackingService ?? DriverTrackingService();
  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;
  String? get _uid =>
      widget.uid ??
      (widget.firestore != null
          ? null
          : FirebaseAuth.instance.currentUser?.uid);
  final _mapController = MapController();

  RouteResult? _route;
  LatLng? _routeOrigin;
  DateTime? _routeFetchedAt;
  bool _fetchingRoute = false;

  /// Recalcule l'itinéraire réel (OSRM) vers le point de départ du client au
  /// plus une fois toutes les 15s, ou si le chauffeur s'est déplacé de plus
  /// de 30m depuis le dernier calcul — même logique que côté client (voir
  /// `booking_screen.dart`), pour ne pas bombarder le serveur public à
  /// chaque tick de position. Best-effort : un échec laisse simplement
  /// l'ancien tracé affiché.
  void _maybeFetchRoute(LatLng origin, LatLng destination) {
    if (_fetchingRoute) return;
    final now = DateTime.now();
    final stale =
        _routeFetchedAt == null ||
        now.difference(_routeFetchedAt!) > const Duration(seconds: 15);
    final moved =
        _routeOrigin == null ||
        Geolocator.distanceBetween(
              origin.latitude,
              origin.longitude,
              _routeOrigin!.latitude,
              _routeOrigin!.longitude,
            ) >
            30;
    if (!stale && !moved) return;

    _fetchingRoute = true;
    final fetcher = widget.routeFetcher ?? RoutingService.fetchRoute;
    fetcher(from: origin, to: destination).then((result) {
      _fetchingRoute = false;
      if (!mounted || result == null) return;
      setState(() {
        _route = result;
        _routeOrigin = origin;
        _routeFetchedAt = DateTime.now();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _recoverActiveRide();
    _trackingService.position.addListener(_followFirstFix);
    // Position réelle dès l'ouverture (même hors ligne) pour que la carte
    // ne reste pas calée sur Pointe-Noire quand le chauffeur est ailleurs.
    _recenterOnMe(silent: true);
  }

  bool _hasFix = false;

  /// Au premier relevé GPS, la carte se centre sur le chauffeur au lieu de
  /// rester sur la position par défaut.
  void _followFirstFix() {
    final p = _trackingService.position.value;
    if (p == null || _hasFix || !mounted) return;
    _hasFix = true;
    try {
      _mapController.move(p, 15);
    } catch (e, st) {
      ErrorReporter.report(e, st, context: 'driver_home.move_map_15');
    }
  }

  /// Bouton GPS : relit la vraie position, la publie (le dispatch s'appuie
  /// dessus) et recentre la carte.
  Future<void> _recenterOnMe({bool silent = false}) async {
    final p = await _trackingService.locateNow();
    if (!mounted) return;
    if (p == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.driverLocateFailed)),
        );
      }
      return;
    }
    _hasFix = true;
    try {
      _mapController.move(p, 16);
    } catch (e, st) {
      ErrorReporter.report(e, st, context: 'driver_home.move_map_16');
    }
  }

  Future<void> _recoverActiveRide() async {
    final uid = _uid;
    if (uid == null) return;
    final doc = await UserRepository(_db).getUser(uid);
    final activeId = doc.data()?['driverActiveRideId'] as String?;
    final wasOnline = doc.data()?['driverOnline'] as bool? ?? false;
    if (!mounted) return;
    if (activeId != null) {
      setState(() => _activeRideId = activeId);
    }
    // Le statut en ligne/hors ligne n'était jusqu'ici qu'un état local
    // (`_online`), perdu à chaque redémarrage de l'app (l'OS tuant le
    // process en tâche de fond, par ex.) — le chauffeur se retrouvait
    // hors ligne sans le savoir. On le persiste donc (voir _toggleOnline)
    // et on relance le suivi GPS ici pour rester cohérent avec ce qui est
    // affiché à l'écran.
    if (wasOnline) {
      setState(() => _online = true);
      _trackingService.startTracking();
    }
  }

  @override
  void dispose() {
    _trackingService.position.removeListener(_followFirstFix);
    _trackingService.stopTracking();
    super.dispose();
  }

  void _toggleOnline(bool value) {
    if (value && emailVerificationBlocksAction()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.emailVerifyRequired)),
      );
      return;
    }
    setState(() => _online = value);
    final uid = _uid;
    if (uid != null) {
      UserRepository(_db).updateUser(uid, {'driverOnline': value});
    }
    if (value) {
      _trackingService.startTracking();
    } else {
      _trackingService.stopTracking();
    }
  }

  Future<void> _respondToOffer(RideRequest request, bool accept) async {
    final id = request.id;
    if (id == null) return;
    try {
      await DispatchResponseService.respond(rideId: id, accept: accept);
      if (!mounted || !accept) return;
      await _waitForAssignmentConfirmation(id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.driverRequestTaken)),
      );
    }
  }

  /// Un 200 de `/api/rides/respond` signifie seulement que le hook serveur
  /// a été relancé — le workflow peut encore rejeter l'assignation ensuite
  /// (solde insuffisant, course déjà réassignée...). On attend donc la
  /// confirmation réelle (status == accepted && driverUid == ce chauffeur)
  /// sur ride_requests/{id} avant de basculer sur l'écran de course active,
  /// avec un délai bercé un peu au-delà de la fenêtre d'offre serveur de
  /// 12s pour couvrir la latence réseau.
  Future<void> _waitForAssignmentConfirmation(String id) async {
    final uid = _uid;
    final completer = Completer<bool>();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subscription;
    Timer? timeoutTimer;

    subscription = RideRepository(_db).watchRide(id).listen((snapshot) {
      final data = snapshot.data();
      if (data != null &&
          data['status'] == 'accepted' &&
          data['driverUid'] == uid) {
        if (!completer.isCompleted) completer.complete(true);
      }
    });

    timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) completer.complete(false);
    });

    final confirmed = await completer.future;
    await subscription.cancel();
    timeoutTimer.cancel();

    if (!mounted) return;
    if (confirmed) {
      setState(() {
        _activeRideId = id;
        _route = null;
        _routeOrigin = null;
        _routeFetchedAt = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.driverRequestTaken)),
      );
    }
  }

  /// Le client a annulé pendant que la course était active : on libère le
  /// chauffeur (état local + `driverActiveRideId` + accès à la position du
  /// client) pour qu'il redevienne disponible, sans réécrire le statut de
  /// la course, déjà `cancelled`.
  Future<void> _releaseCancelledRide() async {
    final id = _activeRideId;
    final uid = _uid;
    if (id == null) return;
    setState(() {
      _activeRideId = null;
      _route = null;
      _routeOrigin = null;
      _routeFetchedAt = null;
    });
    if (uid != null) {
      await RideRepository(_db).releaseDriver(uid);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.driverRideCancelledByClient)),
    );
  }

  Future<void> _endRide(RideStatus newStatus) async {
    final id = _activeRideId;
    if (id == null) return;
    final uid = _uid;
    await RideRepository(_db)
        .finishRide(rideId: id, status: newStatus, driverUid: uid);
    if (newStatus == RideStatus.completed) {
      try {
        await PaymentService.chargeCommission(rideId: id);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.driverCommissionError)),
          );
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _activeRideId = null;
      _route = null;
      _routeOrigin = null;
      _routeFetchedAt = null;
    });
  }

  /// Fait avancer la course d'une étape (accepted → arrived → inProgress),
  /// sans toucher au reste de la session chauffeur (contrairement à
  /// `_endRide`) : la course reste active, `driverActiveRideId` inchangé.
  /// L'ancien itinéraire est effacé pour que le prochain rendu recalcule
  /// tout de suite vers la bonne cible (pickup → destination une fois à
  /// bord) plutôt que d'afficher un tracé périmé jusqu'au prochain
  /// déplacement du chauffeur.
  Future<void> _advanceRide(RideStatus newStatus) async {
    final id = _activeRideId;
    if (id == null) return;
    await RideRepository(_db)
        .updateRide(id, {'status': newStatus.firestoreValue});
    if (!mounted) return;
    setState(() {
      _route = null;
      _routeOrigin = null;
      _routeFetchedAt = null;
    });
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

            if (_online && !hasBalance && _activeRideId == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _toggleOnline(false);
              });
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      DriverHeader(
                        driverName: widget.driverName,
                        online: _online,
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
                        online: _online,
                        canToggle: hasBalance && _activeRideId == null,
                        onChanged: (value) => _toggleOnline(value),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: _activeRideId != null
                      ? ActiveRide(
                          rideId: _activeRideId!,
                          onEnd: _endRide,
                          onAdvance: _advanceRide,
                          onClientCancelled: _releaseCancelledRide,
                          onUnavailable: () => setState(() {
                            _activeRideId = null;
                            _route = null;
                            _routeOrigin = null;
                            _routeFetchedAt = null;
                          }),
                          firestore: _db,
                          eta: _route?.duration,
                        )
                      : !hasBalance
                      ? const BalanceRequiredNotice()
                      : !_online
                      ? const OfflineNotice()
                      : RideOfferCard(
                          onRespond: _respondToOffer,
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
                        activeRideId: _activeRideId,
                        route: _route,
                        onNeedRoute: _maybeFetchRoute,
                        onRecenter: _recenterOnMe,
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
