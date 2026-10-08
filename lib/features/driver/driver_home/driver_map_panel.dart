import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/ride_request.dart';
import '../../../repositories/driver_repository.dart';
import '../../../repositories/ride_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/routing_service.dart';
import 'map_control_button.dart';

/// Carte de l'écran chauffeur : position du chauffeur, point de départ,
/// position du client et itinéraire courant.
class DriverMapPanel extends StatelessWidget {
  const DriverMapPanel({
    super.key,
    required this.mapController,
    required this.firestore,
    required this.uid,
    required this.activeRideId,
    required this.route,
    required this.onNeedRoute,
    required this.onRecenter,
  });

  final MapController mapController;
  final FirebaseFirestore firestore;
  final String? uid;
  final String? activeRideId;
  final RouteResult? route;
  final void Function(LatLng origin, LatLng destination) onNeedRoute;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final uid = this.uid;
    return SizedBox(
      height: 180,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: const MapOptions(
                  initialCenter: AppConfig.defaultMapCenter,
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.yame.yame',
                  ),
                  if (uid != null)
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: DriverRepository(firestore).watchLocation(uid),
                      builder: (context, locSnap) {
                        final data = locSnap.data?.data();
                        LatLng? driverPos;
                        if (data != null &&
                            data['lat'] != null &&
                            data['lng'] != null) {
                          driverPos = LatLng(
                            (data['lat'] as num).toDouble(),
                            (data['lng'] as num).toDouble(),
                          );
                        }

                        final driverMarker = driverPos == null
                            ? null
                            : Marker(
                                point: driverPos,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.directions_car_rounded,
                                  color: AppColors.accent,
                                  size: 28,
                                ),
                              );

                        if (activeRideId == null) {
                          return MarkerLayer(
                            markers: [?driverMarker],
                          );
                        }

                        return StreamBuilder<
                          DocumentSnapshot<Map<String, dynamic>>
                        >(
                          stream: RideRepository(firestore)
                              .watchRide(activeRideId),
                          builder: (context, rideSnap) {
                            final rideData = rideSnap.data?.data();
                            final pickupMap =
                                rideData?['pickup'] as Map<String, dynamic>?;
                            final destinationMap =
                                rideData?['destination']
                                    as Map<String, dynamic>?;
                            final rideStatus = rideData?['status'] as String?;
                            final clientUid = rideData?['clientUid'] as String?;
                            LatLng? pickup;
                            if (pickupMap != null) {
                              pickup = LatLng(
                                (pickupMap['lat'] as num).toDouble(),
                                (pickupMap['lng'] as num).toDouble(),
                              );
                            }
                            LatLng? destination;
                            if (destinationMap != null) {
                              destination = LatLng(
                                (destinationMap['lat'] as num).toDouble(),
                                (destinationMap['lng'] as num).toDouble(),
                              );
                            }

                            // Avant l'arrivée : itinéraire vers le client.
                            // Une fois à bord : itinéraire vers la destination.
                            // "Arrivé" (entre les deux) : pas de tracé, ETA = 0.
                            if (driverPos != null &&
                                rideStatus ==
                                    RideStatus.accepted.firestoreValue &&
                                pickup != null) {
                              onNeedRoute(driverPos, pickup);
                            } else if (driverPos != null &&
                                rideStatus ==
                                    RideStatus.inProgress.firestoreValue &&
                                destination != null) {
                              onNeedRoute(driverPos, destination);
                            }

                            return StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: clientUid == null
                                  ? const Stream.empty()
                                  : UserRepository(firestore)
                                        .watchClientLocation(clientUid),
                              builder: (context, clientLocSnap) {
                                final clientData = clientLocSnap.data?.data();
                                LatLng? clientPos;
                                if (clientData != null &&
                                    clientData['lat'] != null &&
                                    clientData['lng'] != null) {
                                  clientPos = LatLng(
                                    (clientData['lat'] as num).toDouble(),
                                    (clientData['lng'] as num).toDouble(),
                                  );
                                }

                                return Stack(
                                  children: [
                                    if (route != null)
                                      PolylineLayer(
                                        polylines: [
                                          Polyline(
                                            points: route!.polyline,
                                            strokeWidth: 4,
                                            color: AppColors.accent,
                                          ),
                                        ],
                                      ),
                                    MarkerLayer(
                                      markers: [
                                        ?driverMarker,
                                        if (pickup != null)
                                          Marker(
                                            point: pickup,
                                            width: 36,
                                            height: 36,
                                            child: const Icon(
                                              Icons.location_on,
                                              color: Colors.green,
                                              size: 36,
                                            ),
                                          ),
                                        if (clientPos != null)
                                          Marker(
                                            point: clientPos,
                                            width: 22,
                                            height: 22,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.blueAccent,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 3,
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black38,
                                                    blurRadius: 4,
                                                  ),
                                                ],
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
              Positioned(
                right: 10,
                bottom: 10,
                child: MapControlButton(
                  icon: Icons.my_location_rounded,
                  onTap: onRecenter,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
