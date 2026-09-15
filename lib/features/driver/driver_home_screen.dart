import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ride_request.dart';
import '../../models/vehicle_type.dart';
import '../../routes/app_routes.dart';
import '../../services/dispatch_response_service.dart';
import '../../services/driver_tracking_service.dart';
import '../support/report_issue_screen.dart';
import 'contact_passenger_screen.dart';
import 'driver_dashboard_screen.dart';
import 'recharge_screen.dart';

/// Écran chauffeur : bascule en ligne/hors ligne, liste des demandes de
/// course ouvertes pour son type de véhicule, et suivi de la course acceptée.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({
    super.key,
    required this.vehicleType,
    required this.driverName,
  });

  final VehicleType vehicleType;
  final String driverName;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _online = false;
  String? _activeRideId;
  final DriverTrackingService _trackingService = DriverTrackingService();

  @override
  void initState() {
    super.initState();
    _recoverActiveRide();
  }

  Future<void> _recoverActiveRide() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
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
    _trackingService.stopTracking();
    super.dispose();
  }

  void _toggleOnline(bool value) {
    setState(() => _online = value);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'driverOnline': value});
    }
    if (value) {
      _trackingService.startTracking();
    } else {
      _trackingService.stopTracking();
    }
  }


  Future<void> _logout() async {
    if (_online) _toggleOnline(false);
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.onboarding, (route) => false);
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final completer = Completer<bool>();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subscription;
    Timer? timeoutTimer;

    subscription = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(id)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          if (data != null && data['status'] == 'accepted' && data['driverUid'] == uid) {
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
      setState(() => _activeRideId = id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.driverRequestTaken)),
      );
    }
  }

  Future<void> _endRide(RideStatus newStatus) async {
    final id = _activeRideId;
    if (id == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final batch = FirebaseFirestore.instance.batch()
      ..update(FirebaseFirestore.instance.collection('ride_requests').doc(id), {
        'status': newStatus.firestoreValue,
      });
    if (uid != null) {
      // Révoque l'accès du client à la position GPS live maintenant que
      // la course est terminée/annulée.
      batch.set(
        FirebaseFirestore.instance
            .collection('driver_profiles')
            .doc(uid)
            .collection('location')
            .doc('current'),
        {'activeClientUid': FieldValue.delete()},
        SetOptions(merge: true),
      );
      batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
        'driverActiveRideId': null,
      });
    }
    await batch.commit();
    if (!mounted) return;
    setState(() => _activeRideId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: '${AppStrings.homeGreeting} '),
                          TextSpan(
                            text: widget.driverName,
                            style: const TextStyle(
                              color: AppColors.accentBright,
                            ),
                          ),
                        ],
                      ),
                      style: Theme.of(context).textTheme.displayLarge
                          ?.copyWith(fontSize: 24),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RechargeScreen()),
                    ),
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    tooltip: AppStrings.driverWallet,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DriverDashboardScreen(driverName: widget.driverName),
                      ),
                    ),
                    icon: const Icon(Icons.dashboard_outlined),
                    tooltip: AppStrings.driverDashboardTooltip,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ReportIssueScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.report_problem_outlined),
                    tooltip: AppStrings.reportTitle,
                  ),
                  IconButton(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    tooltip: AppStrings.logout,
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('driver_profiles')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection('wallet')
                    .doc('current')
                    .snapshots(),
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
                  final balance =
                      snapshot.data?.data()?['balance'] as int? ?? 0;
                  final hasBalance = balance > 0;

                  if (_online && !hasBalance && _activeRideId == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _toggleOnline(false);
                    });
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _online
                                      ? AppColors.success
                                      : AppColors.textDisabled,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _online
                                      ? AppStrings.driverOnline
                                      : AppStrings.driverOffline,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontSize: 16),
                                ),
                              ),
                              Switch(
                                value: _online,
                                activeThumbColor: AppColors.accent,
                                onChanged: _activeRideId == null && hasBalance
                                    ? (value) => _toggleOnline(value)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: _activeRideId != null
                            ? _ActiveRide(
                                rideId: _activeRideId!,
                                onEnd: _endRide,
                                onUnavailable: () => setState(() => _activeRideId = null),
                              )
                            : !hasBalance
                            ? const _BalanceRequiredNotice()
                            : !_online
                            ? const _OfflineNotice()
                            : _RideOfferCard(
                                onRespond: _respondToOffer,
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.power_settings_new_rounded,
                size: 32,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.driverGoOnline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceRequiredNotice extends StatelessWidget {
  const _BalanceRequiredNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 32,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.driverBalanceRequired,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RechargeScreen()),
                ),
                child: const Text(AppStrings.driverBalanceRequiredCta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RideOfferCard extends StatelessWidget {
  const _RideOfferCard({required this.onRespond});

  final void Function(RideRequest request, bool accept) onRespond;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: uid == null
          ? null
          : FirebaseFirestore.instance
              .collection('ride_requests')
              .where('offeredUid', isEqualTo: uid)
              .where('status', isEqualTo: RideStatus.searching.firestoreValue)
              .limit(1)
              .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 40,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.driverNoRequests,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        final request = RideRequest.fromDoc(docs.first);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.clientName.isNotEmpty ? request.clientName : AppStrings.driverClient,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _AddressRow(
                  icon: Icons.circle,
                  iconColor: AppColors.success,
                  label: AppStrings.driverPickup,
                  address: request.pickupAddress,
                ),
                const SizedBox(height: 8),
                _AddressRow(
                  icon: Icons.location_on,
                  iconColor: AppColors.accent,
                  label: AppStrings.driverDestination,
                  address: request.destinationAddress,
                ),
                if (request.offerExpiresAt != null) ...[
                  const SizedBox(height: 12),
                  _OfferCountdown(expiresAt: request.offerExpiresAt!),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onRespond(request, false),
                        child: const Text(AppStrings.driverDecline),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => onRespond(request, true),
                        child: const Text(AppStrings.driverAccept),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OfferCountdown extends StatefulWidget {
  const _OfferCountdown({required this.expiresAt});

  final DateTime expiresAt;

  @override
  State<_OfferCountdown> createState() => _OfferCountdownState();
}

class _OfferCountdownState extends State<_OfferCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expiresAt.difference(DateTime.now()).inSeconds;
    final seconds = remaining > 0 ? remaining : 0;
    return Text(
      '${AppStrings.driverOfferExpiresIn} ${seconds}s',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.accentBright),
    );
  }
}

class _ActiveRide extends StatelessWidget {
  const _ActiveRide({
    required this.rideId,
    required this.onEnd,
    required this.onUnavailable,
  });

  final String rideId;
  final ValueChanged<RideStatus> onEnd;
  final VoidCallback onUnavailable;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(rideId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          // Le chauffeur a perdu l'accès au document (course annulée/
          // réassignée entre-temps) : un écran blanc serait bloquant, on
          // propose donc de revenir à la carte d'offre plutôt que de
          // laisser le chauffeur coincé.
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.driverActiveRideUnavailable,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: onUnavailable,
                    child: const Text(AppStrings.driverActiveRideUnavailableCta),
                  ),
                ],
              ),
            ),
          );
        }
        final request = RideRequest.fromDoc(snapshot.data!);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  AppStrings.driverAcceptedRide,
                  style: const TextStyle(
                    color: AppColors.accentBright,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.clientName.isNotEmpty
                          ? request.clientName
                          : AppStrings.driverClient,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    _AddressRow(
                      icon: Icons.circle,
                      iconColor: AppColors.success,
                      label: AppStrings.driverPickup,
                      address: request.pickupAddress,
                    ),
                    const SizedBox(height: 8),
                    _AddressRow(
                      icon: Icons.location_on,
                      iconColor: AppColors.accent,
                      label: AppStrings.driverDestination,
                      address: request.destinationAddress,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ContactPassengerScreen(ride: request),
                    ),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text(AppStrings.driverContactPassenger),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => onEnd(RideStatus.completed),
                  child: const Text(AppStrings.driverComplete),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => onEnd(RideStatus.cancelled),
                  child: const Text(AppStrings.driverCancelRide),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(icon, size: 12, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label — ${address ?? '…'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
