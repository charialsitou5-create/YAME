import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/fare.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/vehicle_type.dart';
import '../recipient_details_screen.dart';
import 'pick_mode.dart';
import 'location_tile.dart';
import 'vehicle_type_card.dart';
import 'recipient_row.dart';

class BookingPanel extends StatelessWidget {
  const BookingPanel({
    super.key,
    required this.pickMode,
    required this.vehicleType,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.hasPickup,
    required this.hasDestination,
    required this.estimatedPrice,
    required this.canRequest,
    required this.submitting,
    required this.recipient,
    required this.onPick,
    required this.onVehicleChanged,
    required this.onRequest,
    required this.onEditRecipient,
    required this.onClearRecipient,
  });

  final PickMode pickMode;
  final VehicleType vehicleType;
  final String? pickupAddress;
  final String? destinationAddress;
  final bool hasPickup;
  final bool hasDestination;
  final int? estimatedPrice;
  final bool canRequest;
  final bool submitting;
  final RideRecipient? recipient;
  final ValueChanged<PickMode> onPick;
  final ValueChanged<VehicleType> onVehicleChanged;
  final VoidCallback onRequest;
  final VoidCallback onEditRecipient;
  final VoidCallback onClearRecipient;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LocationTile(
                icon: Icons.circle,
                iconColor: AppColors.success,
                label: AppStrings.bookingPickupLabel,
                value: pickupAddress,
                hint: AppStrings.bookingPickupHint,
                selected: pickMode == PickMode.pickup,
                hasPoint: hasPickup,
                onTap: () => onPick(PickMode.pickup),
              ),
              const SizedBox(height: 10),
              LocationTile(
                icon: Icons.location_on,
                iconColor: AppColors.accent,
                label: AppStrings.bookingDestinationLabel,
                value: destinationAddress,
                hint: AppStrings.bookingDestinationHint,
                selected: pickMode == PickMode.destination,
                hasPoint: hasDestination,
                onTap: () => onPick(PickMode.destination),
              ),
              const SizedBox(height: 16),
              Row(
                children: VehicleType.values.map((type) {
                  final selected = type == vehicleType;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: type == VehicleType.values.first ? 10 : 0,
                      ),
                      child: VehicleTypeCard(
                        type: type,
                        selected: selected,
                        onTap: () => onVehicleChanged(type),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              RecipientRow(
                recipient: recipient,
                onEdit: onEditRecipient,
                onClear: onClearRecipient,
              ),
              if (estimatedPrice != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      AppStrings.bookingEstimatedPrice,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${formatFcfa(estimatedPrice!)} FCFA',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (canRequest && !submitting) ? onRequest : null,
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(AppStrings.bookingCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
