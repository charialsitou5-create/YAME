
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/ride_request.dart';
import '../../../services/routing_service.dart';
import '../contact_passenger_screen.dart';
import 'address_row.dart';

class ActiveRide extends StatelessWidget {
  const ActiveRide({
    super.key,
    required this.rideId,
    required this.onEnd,
    required this.onAdvance,
    required this.onUnavailable,
    required this.onClientCancelled,
    required this.firestore,
    required this.eta,
  });

  final FirebaseFirestore firestore;
  final String rideId;
  final ValueChanged<RideStatus> onEnd;

  /// Fait passer la course à l'étape suivante (accepted → arrived →
  /// inProgress) — distinct de [onEnd], qui termine ou annule la course.
  final ValueChanged<RideStatus> onAdvance;
  final VoidCallback onUnavailable;
  final VoidCallback onClientCancelled;

  /// Durée estimée jusqu'à la prochaine étape — point de départ du client
  /// tant que la course est `accepted`, destination une fois `inProgress` —
  /// calculée via `RoutingService` (OSRM). `null` tant qu'aucun itinéraire
  /// n'a encore été reçu, ou hors sujet à l'étape `arrived` (ETA = 0).
  final Duration? eta;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestore
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
                    child: const Text(
                      AppStrings.driverActiveRideUnavailableCta,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final request = RideRequest.fromDoc(snapshot.data!);
        if (request.status == RideStatus.cancelled) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onClientCancelled());
          return const SizedBox.shrink();
        }
        final badgeText = switch (request.status) {
          RideStatus.accepted => AppStrings.driverStatusEnRoute,
          RideStatus.arrived => AppStrings.driverStatusArrived,
          _ => AppStrings.driverAcceptedRide,
        };
        final etaPrefix = request.status == RideStatus.inProgress
            ? AppStrings.driverEtaToDestinationPrefix
            : AppStrings.driverEtaToPickupPrefix;
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
                  badgeText,
                  style: const TextStyle(
                    color: AppColors.accentBright,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (eta != null && request.status != RideStatus.arrived) ...[
                const SizedBox(height: 10),
                Text(
                  '$etaPrefix ${formatEta(eta!)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: switch (request.status) {
                    RideStatus.accepted => () => onAdvance(RideStatus.arrived),
                    RideStatus.arrived => () => onAdvance(RideStatus.inProgress),
                    _ => () => onEnd(RideStatus.completed),
                  },
                  child: Text(switch (request.status) {
                    RideStatus.accepted => AppStrings.driverMarkArrived,
                    RideStatus.arrived => AppStrings.driverStartRide,
                    _ => AppStrings.driverComplete,
                  }),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surfaceElevated,
                        title: const Text(AppStrings.driverCancelConfirmTitle),
                        content: const Text(AppStrings.driverCancelConfirmBody),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text(
                              AppStrings.driverCancelConfirmKeep,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              AppStrings.driverCancelConfirmYes,
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) onEnd(RideStatus.cancelled);
                  },
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
