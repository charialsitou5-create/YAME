import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_strings.dart';
import '../../core/fare.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ride_request.dart';
import '../../models/vehicle_type.dart';
import '../../routes/app_routes.dart';
import '../../services/client_tracking_service.dart';
import '../../services/dispatch_service.dart';
import '../../services/routing_service.dart';
import 'cancel_reason_screen.dart';
import 'location_picker_screen.dart';
import 'payment_screen.dart';
import 'rating_screen.dart';
import 'recipient_details_screen.dart';
import 'share_position_screen.dart';
import '../../services/error_reporter.dart';
import '../../repositories/driver_repository.dart';
import '../../repositories/ride_repository.dart';
import '../../repositories/user_repository.dart';

/// Coordonnées approximatives du centre de Pointe-Noire, utilisées tant que
/// la position de l'utilisateur n'est pas connue.
const _pointeNoireCenter = LatLng(-4.7889, 11.8656);

enum _PickMode { pickup, destination }

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, this.initialVehicleType = VehicleType.car});

  final VehicleType initialVehicleType;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _geocoding = Geocoding();
  final MapController _mapController = MapController();

  LatLng? _pickupPosition;
  LatLng? _destinationPosition;
  String? _pickupAddress;
  String? _destinationAddress;

  _PickMode _pickMode = _PickMode.pickup;
  late VehicleType _vehicleType = widget.initialVehicleType;

  /// Dernier point connu de l'utilisateur (sinon Pointe-Noire par défaut).
  LatLng _lastKnownCenter = _pointeNoireCenter;
  bool _locating = true;
  String? _locationError;

  String? _activeRequestId;
  bool _submittingRequest = false;
  RideRecipient? _recipient;
  bool _clientActiveRideCleared = false;
  FarePricing? _pricing;

  final _clientTracking = ClientTrackingService();
  RouteResult? _route;
  LatLng? _routeOrigin;
  DateTime? _routeFetchedAt;
  bool _fetchingRoute = false;

  int? get _estimatedPrice {
    if (_pickupPosition == null || _destinationPosition == null) return null;
    return estimateFareFcfa(
      pickup: _pickupPosition!,
      destination: _destinationPosition!,
      vehicleType: _vehicleType,
      pricing: _pricing ?? FarePricing.defaults,
    );
  }

  @override
  void initState() {
    super.initState();
    _locateMe();
    _recoverActiveRequest();
    loadFarePricing().then((p) {
      if (mounted) setState(() => _pricing = p);
    });
  }

  Future<void> _recoverActiveRequest() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await UserRepository().getUser(uid);
    final activeId = doc.data()?['clientActiveRideId'] as String?;
    if (activeId != null && mounted) {
      setState(() => _activeRequestId = activeId);
      unawaited(_clientTracking.startTracking());
    }
  }

  @override
  void dispose() {
    _clientTracking.stopTracking();
    super.dispose();
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
        if (!mounted) return;
        setState(() {
          _locationError = AppStrings.bookingLocationDenied;
          _locating = false;
        });
        return;
      }

      // Position en cache d'abord (instantanée) pour ne jamais laisser la
      // carte sur Pointe-Noire quand l'utilisateur est ailleurs, puis une
      // lecture fraîche avec délai maximal (sinon le GPS pouvait bloquer).
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) {
        _lastKnownCenter = LatLng(cached.latitude, cached.longitude);
        try {
          _mapController.move(_lastKnownCenter, 15);
        } catch (e, st) {
          ErrorReporter.report(e, st, context: 'booking.move_cached_center');
          }
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      _lastKnownCenter = latLng;
      await _setPoint(_PickMode.pickup, latLng, animateCamera: true);
    } catch (_) {
      if (mounted)
        setState(() => _locationError = AppStrings.bookingLocationDenied);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _setPoint(
    _PickMode mode,
    LatLng point, {
    bool animateCamera = false,
  }) async {
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
      try {
        _mapController.move(point, 15);
      } catch (e, st) {
        ErrorReporter.report(e, st, context: 'booking.move_camera');
        }
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

  /// Ouvre la carte plein écran (avec recherche écrite) pour le champ touché.
  Future<void> _pickOnFullMap(_PickMode mode) async {
    final isPickup = mode == _PickMode.pickup;
    final current = isPickup ? _pickupPosition : _destinationPosition;
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: isPickup
              ? AppStrings.bookingPickupLabel
              : AppStrings.bookingDestinationLabel,
          initialCenter: _pickupPosition ?? _lastKnownCenter,
          initialPoint: current,
          pinColor: isPickup ? Colors.green : Colors.orange,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (isPickup) {
        _pickupPosition = result.point;
        _pickupAddress = result.address;
      } else {
        _destinationPosition = result.point;
        _destinationAddress = result.address;
      }
    });
    if (result.address == null) {
      final address = await _reverseGeocode(result.point);
      if (!mounted) return;
      setState(() {
        if (isPickup) {
          _pickupAddress = address;
        } else {
          _destinationAddress = address;
        }
      });
    }
    try {
      _mapController.move(result.point, 15);
    } catch (e, st) {
      ErrorReporter.report(e, st, context: 'booking.move_to_result');
      }
  }

  Future<void> _editRecipient() async {
    final result = await Navigator.of(context).push<RideRecipient>(
      MaterialPageRoute(
        builder: (_) => RecipientDetailsScreen(initial: _recipient),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _recipient = result);
  }

  void _clearRecipient() => setState(() => _recipient = null);

  Future<void> _logout() async {
    // Action irréversible et destructrice (perd la sélection départ/
    // destination en cours) déclenchée par une icône dans le coin où
    // l'utilisateur s'attend d'ordinaire à un bouton retour — une
    // confirmation explicite évite une déconnexion accidentelle.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.logoutConfirmTitle),
        content: const Text(AppStrings.logoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.bookingCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              AppStrings.logout,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.onboarding, (route) => false);
  }

  Future<void> _requestDriver() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _pickupPosition == null || _destinationPosition == null)
      return;

    setState(() => _submittingRequest = true);
    try {
      final profile = await UserRepository().getUser(user.uid);
      final clientName = profile.data()?['name'] as String? ?? '';

      final request = RideRequest(
        clientUid: user.uid,
        clientName: clientName,
        pickup: _pickupPosition!,
        pickupAddress: _pickupAddress,
        destination: _destinationPosition!,
        destinationAddress: _destinationAddress,
        vehicleType: _vehicleType,
        status: RideStatus.searching,
        recipientName: _recipient?.name,
        recipientPhone: _recipient?.phone,
        recipientInstructions: _recipient?.instructions,
        contactRequesterInstead: _recipient?.contactRequesterInstead ?? false,
        price: _estimatedPrice,
      );
      final requestId = await RideRepository().createRequest(
        clientUid: user.uid,
        data: request.toMap(),
      );

      if (!mounted) return;
      setState(() {
        _activeRequestId = requestId;
        _clientActiveRideCleared = false;
      });
      unawaited(_clientTracking.startTracking());

      try {
        await DispatchService.start(rideId: requestId);
      } catch (e) {
        debugPrint('Dispatch failed: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.bookingRequestError)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.bookingRequestError)),
      );
    } finally {
      if (mounted) setState(() => _submittingRequest = false);
    }
  }

  Future<void> _cancelRequest({required String reason, String? comment}) async {
    final id = _activeRequestId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (id == null || uid == null) return;
    await RideRepository().cancelByClient(
      rideId: id,
      clientUid: uid,
      reason: reason,
      comment: comment,
    );
    _clientActiveRideCleared = true;
    unawaited(_clientTracking.stopTracking());
  }

  /// Recalcule l'itinéraire réel (OSRM) chauffeur → point de départ au plus
  /// une fois toutes les 15s, ou si le chauffeur s'est déplacé de plus de
  /// 30m depuis le dernier calcul — pour ne pas bombarder le serveur public
  /// à chaque tick de position (mise à jour tous les 10m côté chauffeur).
  /// Best-effort : un échec (réseau, service indisponible) laisse
  /// simplement l'ancien tracé affiché, sans jamais bloquer l'écran.
  void _maybeFetchRoute(LatLng origin, LatLng destination) {
    if (_fetchingRoute) return;
    final now = DateTime.now();
    final stale = _routeFetchedAt == null ||
        now.difference(_routeFetchedAt!) > const Duration(seconds: 15);
    final moved = _routeOrigin == null ||
        Geolocator.distanceBetween(
              origin.latitude,
              origin.longitude,
              _routeOrigin!.latitude,
              _routeOrigin!.longitude,
            ) >
            30;
    if (!stale && !moved) return;

    _fetchingRoute = true;
    RoutingService.fetchRoute(from: origin, to: destination).then((result) {
      _fetchingRoute = false;
      if (!mounted || result == null) return;
      setState(() {
        _route = result;
        _routeOrigin = origin;
        _routeFetchedAt = DateTime.now();
      });
    });
  }

  /// Point bleu "vous êtes ici", distinct du pin de départ (vert) — se
  /// déplace en direct tant que la course est active, pour que le client se
  /// voie bouger sur la carte (voir `ClientTrackingService`).
  Marker _buildMyPositionMarker(LatLng position) {
    return Marker(
      point: position,
      width: 22,
      height: 22,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
        ),
      ),
    );
  }

  List<Marker> _buildStaticMarkers() {
    return [
      if (_pickupPosition != null)
        Marker(
          point: _pickupPosition!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.green, size: 40),
        ),
      if (_destinationPosition != null)
        Marker(
          point: _destinationPosition!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.orange, size: 40),
        ),
    ];
  }

  void _startNewBooking() {
    setState(() {
      _activeRequestId = null;
      _recipient = null;
      _clientActiveRideCleared = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canRequest = _pickupPosition != null && _destinationPosition != null;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pointeNoireCenter,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yame.yame',
              ),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: (_activeRequestId != null &&
                        FirebaseAuth.instance.currentUser != null)
                    ? UserRepository().watchClientLocation(FirebaseAuth.instance.currentUser!.uid)
                    : const Stream.empty(),
                builder: (context, myLocSnap) {
                  final myLocationData = myLocSnap.data?.data();
                  LatLng? myPos;
                  if (myLocationData != null &&
                      myLocationData['lat'] != null &&
                      myLocationData['lng'] != null) {
                    myPos = LatLng(
                      (myLocationData['lat'] as num).toDouble(),
                      (myLocationData['lng'] as num).toDouble(),
                    );
                  }

                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _activeRequestId != null
                        ? RideRepository().watchRide(_activeRequestId)
                        : const Stream.empty(),
                    builder: (context, rideSnap) {
                      final rideData = rideSnap.data?.data();
                      final driverUid = rideData?['driverUid'] as String?;
                      final rideStatus = rideData?['status'] as String?;
                      if (driverUid == null) {
                        return MarkerLayer(
                          markers: [
                            ..._buildStaticMarkers(),
                            if (myPos != null) _buildMyPositionMarker(myPos),
                          ],
                        );
                      }

                      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: DriverRepository().watchLocation(driverUid),
                        builder: (context, driverSnap) {
                          final locationData = driverSnap.data?.data();
                          LatLng? driverPos;
                          if (locationData != null &&
                              locationData['lat'] != null &&
                              locationData['lng'] != null) {
                            driverPos = LatLng(
                              (locationData['lat'] as num).toDouble(),
                              (locationData['lng'] as num).toDouble(),
                            );
                          }

                          // Avant l'arrivée du chauffeur : itinéraire vers le
                          // point de départ. Une fois à bord : itinéraire vers
                          // la destination. "Arrivé" : pas de tracé, ETA = 0.
                          if (driverPos != null &&
                              rideStatus == RideStatus.accepted.firestoreValue &&
                              _pickupPosition != null) {
                            _maybeFetchRoute(driverPos, _pickupPosition!);
                          } else if (driverPos != null &&
                              rideStatus == RideStatus.inProgress.firestoreValue &&
                              _destinationPosition != null) {
                            _maybeFetchRoute(driverPos, _destinationPosition!);
                          }

                          return Stack(
                            children: [
                              if (_route != null)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: _route!.polyline,
                                      strokeWidth: 4,
                                      color: AppColors.accent,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  ..._buildStaticMarkers(),
                                  if (myPos != null) _buildMyPositionMarker(myPos),
                                  if (driverPos != null)
                                    Marker(
                                      point: driverPos,
                                      width: 44,
                                      height: 44,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: AppColors.accent,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black38,
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.directions_car_filled_rounded,
                                          color: Colors.black,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),

          if (_locating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 0,
              right: 0,
              child: Center(
                child: const _StatusPill(
                  icon: Icons.my_location,
                  text: AppStrings.bookingLocatingMe,
                ),
              ),
            )
          else if (_locationError != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 24,
              right: 24,
              child: Center(
                child: _StatusPill(
                  icon: Icons.location_off,
                  text: _locationError!,
                ),
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
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
            top: MediaQuery.of(context).padding.top + 12,
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
            child: _activeRequestId == null
                ? _BookingPanel(
                    pickMode: _pickMode,
                    vehicleType: _vehicleType,
                    pickupAddress: _pickupAddress,
                    destinationAddress: _destinationAddress,
                    hasPickup: _pickupPosition != null,
                    hasDestination: _destinationPosition != null,
                    estimatedPrice: _estimatedPrice,
                    canRequest: canRequest,
                    submitting: _submittingRequest,
                    recipient: _recipient,
                    onPick: _pickOnFullMap,
                    onVehicleChanged: (type) =>
                        setState(() => _vehicleType = type),
                    onRequest: _requestDriver,
                    onEditRecipient: _editRecipient,
                    onClearRecipient: _clearRecipient,
                  )
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: RideRepository().watchRide(_activeRequestId),
                    builder: (context, snapshot) {
                      final doc = snapshot.data;
                      final ride = (doc != null && doc.exists)
                          ? RideRequest.fromDoc(doc)
                          : null;
                      if (ride != null &&
                          !_clientActiveRideCleared &&
                          (ride.status == RideStatus.completed ||
                              ride.status == RideStatus.cancelled ||
                              ride.status == RideStatus.noDriverFound)) {
                        _clientActiveRideCleared = true;
                        unawaited(_clientTracking.stopTracking());
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          UserRepository().updateUser(uid, {'clientActiveRideId': null});
                        }
                      }
                      return _RideStatusPanel(
                        status: ride?.status ?? RideStatus.searching,
                        ride: ride,
                        eta: _route?.duration,
                        onCancel: (reason, comment) =>
                            _cancelRequest(reason: reason, comment: comment),
                        onNewBooking: _startNewBooking,
                      );
                    },
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
          Flexible(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
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

  final _PickMode pickMode;
  final VehicleType vehicleType;
  final String? pickupAddress;
  final String? destinationAddress;
  final bool hasPickup;
  final bool hasDestination;
  final int? estimatedPrice;
  final bool canRequest;
  final bool submitting;
  final RideRecipient? recipient;
  final ValueChanged<_PickMode> onPick;
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
              _LocationTile(
                icon: Icons.circle,
                iconColor: AppColors.success,
                label: AppStrings.bookingPickupLabel,
                value: pickupAddress,
                hint: AppStrings.bookingPickupHint,
                selected: pickMode == _PickMode.pickup,
                hasPoint: hasPickup,
                onTap: () => onPick(_PickMode.pickup),
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
                onTap: () => onPick(_PickMode.destination),
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
                      child: _VehicleTypeCard(
                        type: type,
                        selected: selected,
                        onTap: () => onVehicleChanged(type),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              _RecipientRow(
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

class _VehicleTypeCard extends StatelessWidget {
  const _VehicleTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final VehicleType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.12)
          : AppColors.fieldFill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  type == VehicleType.car
                      ? Icons.directions_car_filled_rounded
                      : Icons.two_wheeler_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                type.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.recipient,
    required this.onEdit,
    required this.onClear,
  });

  final RideRecipient? recipient;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final recipient = this.recipient;
    if (recipient == null) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(
                Icons.person_add_alt_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                AppStrings.orderForSomeoneCta,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_rounded, size: 16, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${AppStrings.orderForSomeonePrefix}${recipient.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton(
              onPressed: onClear,
              tooltip: AppStrings.orderForSomeoneClear,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RideStatusPanel extends StatelessWidget {
  const _RideStatusPanel({
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
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
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
