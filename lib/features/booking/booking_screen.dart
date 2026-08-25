import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/vehicle_type.dart';
import '../../routes/app_routes.dart';

/// Coordonnées approximatives du centre de Pointe-Noire, utilisées tant que
/// la position de l'utilisateur n'est pas connue.
const _pointeNoireCenter = LatLng(-4.7889, 11.8656);

enum _PickMode { pickup, destination }

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _geocoding = Geocoding();
  GoogleMapController? _mapController;

  LatLng? _pickupPosition;
  LatLng? _destinationPosition;
  String? _pickupAddress;
  String? _destinationAddress;

  _PickMode _pickMode = _PickMode.pickup;
  VehicleType _vehicleType = VehicleType.car;

  bool _locating = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _locateMe();
  }

  Future<void> _locateMe() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = AppStrings.bookingLocationDenied;
          _locating = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      await _setPoint(_PickMode.pickup, latLng, animateCamera: true);
    } catch (_) {
      setState(() => _locationError = AppStrings.bookingLocationDenied);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _setPoint(_PickMode mode, LatLng point, {bool animateCamera = false}) async {
    setState(() {
      if (mode == _PickMode.pickup) {
        _pickupPosition = point;
        _pickupAddress = null;
      } else {
        _destinationPosition = point;
        _destinationAddress = null;
      }
    });

    if (animateCamera) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 15));
    }

    final address = await _reverseGeocode(point);
    if (!mounted) return;
    setState(() {
      if (mode == _PickMode.pickup) {
        _pickupAddress = address;
      } else {
        _destinationAddress = address;
      }
    });
  }

  Future<String?> _reverseGeocode(LatLng point) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = [
        p.street,
        p.subLocality,
        p.locality,
      ].whereType<String>().where((part) => part.isNotEmpty);
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  void _onMapTap(LatLng point) {
    _setPoint(_pickMode, point);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.onboarding, (route) => false);
  }

  void _requestDriver() {
    // TODO(yame): remplacer par un vrai appel qui crée une demande de course
    // dans Firestore et déclenche la recherche d'un chauffeur à proximité.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.bookingComingSoon)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRequest = _pickupPosition != null && _destinationPosition != null;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: _pointeNoireCenter, zoom: 13),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTap,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: {
              if (_pickupPosition != null)
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: _pickupPosition!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                ),
              if (_destinationPosition != null)
                Marker(
                  markerId: const MarkerId('destination'),
                  position: _destinationPosition!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                ),
            },
          ),
          if (_locating)
            const Positioned(
              top: 56,
              left: 0,
              right: 0,
              child: Center(
                child: _StatusPill(icon: Icons.my_location, text: AppStrings.bookingLocatingMe),
              ),
            )
          else if (_locationError != null)
            Positioned(
              top: 56,
              left: 24,
              right: 24,
              child: Center(
                child: _StatusPill(icon: Icons.location_off, text: _locationError!),
              ),
            ),
          Positioned(
            top: 56,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'locate-me',
              onPressed: _locateMe,
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.accent,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            top: 56,
            left: 16,
            child: FloatingActionButton.small(
              heroTag: 'logout',
              onPressed: _logout,
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textSecondary,
              tooltip: AppStrings.logout,
              child: const Icon(Icons.logout_rounded),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BookingPanel(
              pickMode: _pickMode,
              vehicleType: _vehicleType,
              pickupAddress: _pickupAddress,
              destinationAddress: _destinationAddress,
              hasPickup: _pickupPosition != null,
              hasDestination: _destinationPosition != null,
              canRequest: canRequest,
              onModeChanged: (mode) => setState(() => _pickMode = mode),
              onVehicleChanged: (type) => setState(() => _vehicleType = type),
              onRequest: _requestDriver,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _BookingPanel extends StatelessWidget {
  const _BookingPanel({
    required this.pickMode,
    required this.vehicleType,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.hasPickup,
    required this.hasDestination,
    required this.canRequest,
    required this.onModeChanged,
    required this.onVehicleChanged,
    required this.onRequest,
  });

  final _PickMode pickMode;
  final VehicleType vehicleType;
  final String? pickupAddress;
  final String? destinationAddress;
  final bool hasPickup;
  final bool hasDestination;
  final bool canRequest;
  final ValueChanged<_PickMode> onModeChanged;
  final ValueChanged<VehicleType> onVehicleChanged;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LocationTile(
            icon: Icons.circle,
            iconColor: AppColors.success,
            label: AppStrings.bookingPickupLabel,
            value: pickupAddress,
            hint: AppStrings.bookingPickupHint,
            selected: pickMode == _PickMode.pickup,
            hasPoint: hasPickup,
            onTap: () => onModeChanged(_PickMode.pickup),
          ),
          const SizedBox(height: 10),
          _LocationTile(
            icon: Icons.location_on,
            iconColor: AppColors.accent,
            label: AppStrings.bookingDestinationLabel,
            value: destinationAddress,
            hint: AppStrings.bookingDestinationHint,
            selected: pickMode == _PickMode.destination,
            hasPoint: hasDestination,
            onTap: () => onModeChanged(_PickMode.destination),
          ),
          const SizedBox(height: 16),
          Row(
            children: VehicleType.values.map((type) {
              final selected = type == vehicleType;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: type == VehicleType.values.first ? 8 : 0),
                  child: OutlinedButton.icon(
                    onPressed: () => onVehicleChanged(type),
                    icon: Icon(
                      type == VehicleType.car
                          ? Icons.directions_car_filled_rounded
                          : Icons.two_wheeler_rounded,
                    ),
                    label: Text(type.label),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: selected ? AppColors.accent.withValues(alpha: 0.12) : null,
                      side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
                      foregroundColor: selected ? AppColors.accent : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: canRequest ? onRequest : null,
            child: const Text(AppStrings.bookingCta),
          ),
        ],
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.hint,
    required this.selected,
    required this.hasPoint,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final String hint;
  final bool selected;
  final bool hasPoint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    hasPoint ? (value ?? '…') : hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
