import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ride_request.dart';
import '../../models/user_role.dart';
import '../../models/vehicle_type.dart';
import '../../routes/app_routes.dart';
import '../../services/driver_tracking_service.dart';
import '../support/report_issue_screen.dart';
import 'contact_passenger_screen.dart';
import 'recharge_screen.dart';

/// Écran chauffeur : bascule en ligne/hors ligne, liste des demandes de
/// course ouvertes pour son type de véhicule, et suivi de la course acceptée.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({
    super.key,
    required this.role,
    required this.driverName,
  });

  final UserRole role;
  final String driverName;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _online = false;
  String? _activeRideId;
  final DriverTrackingService _trackingService = DriverTrackingService();

  VehicleType get _vehicleType => widget.role.vehicleType;

  @override
  void dispose() {
    _trackingService.stopTracking();
    super.dispose();
  }

  void _toggleOnline(bool value) {
    setState(() => _online = value);
    if (value) {
      _trackingService.startTracking();
    } else {
      _trackingService.stopTracking();
    }
  }


  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.onboarding, (route) => false);
  }

  Future<void> _accept(RideRequest request) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final docRef = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(request.id);
    final locationRef = FirebaseFirestore.instance
        .collection('driver_profiles')
        .doc(uid)
        .collection('location')
        .doc('current');

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final currentStatus = snapshot.data()?['status'] as String?;
        if (currentStatus != RideStatus.searching.firestoreValue) {
          throw StateError('taken');
        }
        transaction.update(docRef, {
          'status': RideStatus.accepted.firestoreValue,
          'driverUid': uid,
          'driverName': widget.driverName,
        });
        // Autorise le client de cette course à lire la position GPS live
        // du chauffeur (firestore.rules : driver_profiles/location).
        transaction.set(
          locationRef,
          {'activeClientUid': request.clientUid},
          SetOptions(merge: true),
        );
      });
      if (!mounted) return;
      setState(() => _activeRideId = request.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.driverRequestTaken)),
      );
    }
  }

  Future<void> _endRide(RideStatus newStatus) async {
    final id = _activeRideId;
    if (id == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance.collection('ride_requests').doc(id).update(
      {'status': newStatus.firestoreValue},
    );
    if (uid != null) {
      // Révoque l'accès du client à la position GPS live maintenant que
      // la course est terminée/annulée.
      await FirebaseFirestore.instance
          .collection('driver_profiles')
          .doc(uid)
          .collection('location')
          .doc('current')
          .set({'activeClientUid': FieldValue.delete()}, SetOptions(merge: true));
    }
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
                  final balance =
                      snapshot.data?.data()?['balance'] as int? ?? 0;
                  final hasBalance = balance > 0;

                  if (_online && !hasBalance && _activeRideId == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _online = false);
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
                              )
                            : !hasBalance
                            ? const _BalanceRequiredNotice()
                            : !_online
                            ? const _OfflineNotice()
                            : _PendingRequestsList(
                                vehicleType: _vehicleType,
                                onAccept: _accept,
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

class _PendingRequestsList extends StatelessWidget {
  const _PendingRequestsList({
    required this.vehicleType,
    required this.onAccept,
  });

  final VehicleType vehicleType;
  final ValueChanged<RideRequest> onAccept;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .where('status', isEqualTo: RideStatus.searching.firestoreValue)
          .where('vehicleType', isEqualTo: vehicleType.name)
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

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final request = RideRequest.fromDoc(docs[index]);
            return Container(
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
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => onAccept(request),
                      child: const Text(AppStrings.driverAccept),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ActiveRide extends StatelessWidget {
  const _ActiveRide({required this.rideId, required this.onEnd});

  final String rideId;
  final ValueChanged<RideStatus> onEnd;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(rideId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
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
