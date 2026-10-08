import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/fare.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/ride_request.dart';
import '../../../repositories/ride_repository.dart';
import 'address_row.dart';

class RideOfferCard extends StatelessWidget {
  const RideOfferCard({
    super.key,
    required this.onRespond,
    required this.firestore,
    required this.uid,
  });

  final void Function(RideRequest request, bool accept) onRespond;
  final FirebaseFirestore firestore;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: uid == null
          ? null
          : RideRepository(firestore).watchOfferedRide(uid!),
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
                  request.clientName.isNotEmpty
                      ? request.clientName
                      : AppStrings.driverClient,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                AddressRow(
                  icon: Icons.circle,
                  iconColor: AppColors.success,
                  label: AppStrings.driverPickup,
                  address: request.pickupAddress,
                ),
                const SizedBox(height: 8),
                AddressRow(
                  icon: Icons.location_on,
                  iconColor: AppColors.accent,
                  label: AppStrings.driverDestination,
                  address: request.destinationAddress,
                ),
                if (request.price != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.payments_outlined,
                          size: 12,
                          color: AppColors.accentBright,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${AppStrings.driverOfferPrice} — '
                          '${formatFcfa(request.price!)} FCFA',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.accentBright,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (request.offerExpiresAt != null) ...[
                  const SizedBox(height: 12),
                  OfferCountdown(expiresAt: request.offerExpiresAt!),
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

class OfferCountdown extends StatefulWidget {
  const OfferCountdown({super.key, required this.expiresAt});

  final DateTime expiresAt;

  @override
  State<OfferCountdown> createState() => _OfferCountdownState();
}

class _OfferCountdownState extends State<OfferCountdown> {
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
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: AppColors.accentBright),
    );
  }
}
