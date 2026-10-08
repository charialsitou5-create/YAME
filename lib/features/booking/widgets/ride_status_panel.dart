import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/ride_request.dart';
import '../../../services/routing_service.dart';
import '../cancel_reason_screen.dart';
import '../payment_screen.dart';
import '../rating_screen.dart';
import '../share_position_screen.dart';

class RideStatusPanel extends StatelessWidget {
  const RideStatusPanel({
    super.key,
    required this.status,
    required this.ride,
    required this.eta,
    required this.onCancel,
    required this.onNewBooking,
  });

  final RideStatus status;
  final RideRequest? ride;

  /// Durée estimée du trajet en cours (chauffeur → point de départ), calculée
  /// via `RoutingService` (OSRM) — `null` tant qu'aucun itinéraire n'a
  /// encore été reçu (pas d'affichage plutôt qu'un placeholder trompeur).
  final Duration? eta;
  final void Function(String reason, String? comment) onCancel;
  final VoidCallback onNewBooking;

  Future<void> _cancelWithReason(BuildContext context) async {
    final result = await Navigator.of(context).push<CancelReason>(
      MaterialPageRoute(builder: (_) => const CancelReasonScreen()),
    );
    if (result != null) onCancel(result.reason, result.comment);
  }

  Future<void> _rateDriver(BuildContext context) async {
    final id = ride?.id;
    if (id == null) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => RatingScreen(rideId: id)));
    onNewBooking();
  }

  Future<void> _payRide(BuildContext context) async {
    final currentRide = ride;
    if (currentRide == null) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PaymentScreen(ride: currentRide)));
    onNewBooking();
  }

  Future<void> _sharePosition(BuildContext context) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('denied');
      }
      final position = await Geolocator.getCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      final link =
          'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SharePositionScreen(position: point, link: link),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.bookingSharePositionError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (status) {
          RideStatus.searching => [
            const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(child: Text(AppStrings.bookingSearching)),
              ],
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => _cancelWithReason(context),
              child: const Text(AppStrings.bookingCancel),
            ),
          ],
          RideStatus.accepted => [
            Text(
              AppStrings.bookingAccepted,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              '${ride?.driverName?.isNotEmpty == true ? ride!.driverName : AppStrings.driverClient} ${AppStrings.bookingDriverOnTheWay}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (eta != null) ...[
              const SizedBox(height: 6),
              Text(
                '${AppStrings.bookingDriverEtaPrefix} ${formatEta(eta!)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _sharePosition(context),
              icon: const Icon(Icons.share_location_rounded, size: 18),
              label: const Text(AppStrings.bookingSharePosition),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _cancelWithReason(context),
              child: const Text(AppStrings.bookingCancel),
            ),
          ],
          RideStatus.arrived => [
            Text(
              AppStrings.bookingArrivedTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.bookingArrivedBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _sharePosition(context),
              icon: const Icon(Icons.share_location_rounded, size: 18),
              label: const Text(AppStrings.bookingSharePosition),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _cancelWithReason(context),
              child: const Text(AppStrings.bookingCancel),
            ),
          ],
          RideStatus.inProgress => [
            Text(
              AppStrings.bookingInProgressTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.bookingInProgressBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (eta != null) ...[
              const SizedBox(height: 6),
              Text(
                '${AppStrings.bookingDriverEtaPrefix} ${formatEta(eta!)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
          RideStatus.completed => [
            Text(
              AppStrings.bookingCompletedTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _payRide(context),
              child: const Text(AppStrings.bookingPayRide),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _rateDriver(context),
              child: const Text(AppStrings.bookingRateDriver),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onNewBooking,
              child: const Text(AppStrings.bookingNewRequest),
            ),
          ],
          RideStatus.cancelled => [
            Text(
              AppStrings.bookingCancelled,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onNewBooking,
              child: const Text(AppStrings.bookingNewRequest),
            ),
          ],
          RideStatus.noDriverFound => [
            Text(
              AppStrings.bookingNoDriverFoundTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.bookingNoDriverFoundBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onNewBooking,
              child: const Text(AppStrings.bookingNewRequest),
            ),
          ],
        },
      ),
    );
  }
}
