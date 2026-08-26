import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ride_request.dart';
import '../../models/user_role.dart';
import '../../models/vehicle_type.dart';
import '../../routes/app_routes.dart';

/// Écran chauffeur : bascule en ligne/hors ligne, liste des demandes de
/// course ouvertes pour son type de véhicule, et suivi de la course acceptée.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key, required this.role, required this.driverName});

  final UserRole role;
  final String driverName;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _online = false;
  String? _activeRideId;

  VehicleType get _vehicleType =>
      widget.role == UserRole.chauffeurMoto ? VehicleType.moto : VehicleType.car;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.onboarding, (route) => false);
  }

  Future<void> _accept(RideRequest request) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final docRef = FirebaseFirestore.instance.collection('ride_requests').doc(request.id);

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
    await FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(id)
        .update({'status': newStatus.firestoreValue});
    if (!mounted) return;
    setState(() => _activeRideId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: AppStrings.logout,
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _online ? AppStrings.driverOnline : AppStrings.driverOffline,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Switch(
                    value: _online,
                    activeThumbColor: AppColors.accent,
                    onChanged: _activeRideId == null
                        ? (value) => setState(() => _online = value)
                        : null,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _activeRideId != null
                  ? _ActiveRide(rideId: _activeRideId!, onEnd: _endRide)
                  : !_online
                      ? const _OfflineNotice()
                      : _PendingRequestsList(vehicleType: _vehicleType, onAccept: _accept),
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
            const Icon(Icons.power_settings_new, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              AppStrings.driverGoOnline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRequestsList extends StatelessWidget {
  const _PendingRequestsList({required this.vehicleType, required this.onAccept});

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
              child: Text(
                AppStrings.driverNoRequests,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
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
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.clientName.isNotEmpty ? request.clientName : AppStrings.driverClient,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    _AddressRow(
                      icon: Icons.circle,
                      iconColor: AppColors.success,
                      label: AppStrings.driverPickup,
                      address: request.pickupAddress,
                    ),
                    const SizedBox(height: 6),
                    _AddressRow(
                      icon: Icons.location_on,
                      iconColor: AppColors.accent,
                      label: AppStrings.driverDestination,
                      address: request.destinationAddress,
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () => onAccept(request),
                      child: const Text(AppStrings.driverAccept),
                    ),
                  ],
                ),
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
      stream: FirebaseFirestore.instance.collection('ride_requests').doc(rideId).snapshots(),
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
              Text(AppStrings.driverAcceptedRide, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(
                request.clientName.isNotEmpty ? request.clientName : AppStrings.driverClient,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 14),
              _AddressRow(
                icon: Icons.circle,
                iconColor: AppColors.success,
                label: AppStrings.driverPickup,
                address: request.pickupAddress,
              ),
              const SizedBox(height: 6),
              _AddressRow(
                icon: Icons.location_on,
                iconColor: AppColors.accent,
                label: AppStrings.driverDestination,
                address: request.destinationAddress,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => onEnd(RideStatus.completed),
                child: const Text(AppStrings.driverComplete),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => onEnd(RideStatus.cancelled),
                child: const Text(AppStrings.driverCancelRide),
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
        Icon(icon, size: 12, color: iconColor),
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
