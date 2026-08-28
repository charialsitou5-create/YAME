import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'vehicle_type.dart';

enum RideStatus {
  searching,
  accepted,
  completed,
  cancelled;

  String get firestoreValue => name;

  static RideStatus fromFirestoreValue(String value) {
    return RideStatus.values.firstWhere(
      (status) => status.firestoreValue == value,
      orElse: () => RideStatus.searching,
    );
  }
}

/// Une demande de course, stockée dans Firestore `ride_requests/{id}`.
class RideRequest {
  const RideRequest({
    this.id,
    required this.clientUid,
    required this.clientName,
    required this.pickup,
    required this.pickupAddress,
    required this.destination,
    required this.destinationAddress,
    required this.vehicleType,
    required this.status,
    this.driverUid,
    this.driverName,
    this.recipientName,
    this.recipientPhone,
    this.recipientInstructions,
    this.contactRequesterInstead = false,
  });

  final String? id;
  final String clientUid;
  final String clientName;
  final LatLng pickup;
  final String? pickupAddress;
  final LatLng destination;
  final String? destinationAddress;
  final VehicleType vehicleType;
  final RideStatus status;
  final String? driverUid;
  final String? driverName;

  /// Renseignés quand la course est commandée pour quelqu'un d'autre que
  /// [clientUid] (voir `RecipientDetailsScreen`). `null` sinon.
  final String? recipientName;
  final String? recipientPhone;
  final String? recipientInstructions;

  /// Si vrai, le chauffeur doit contacter le demandeur ([clientName]) plutôt
  /// que la personne transportée pour cette course.
  final bool contactRequesterInstead;

  bool get isForSomeoneElse => recipientName != null;

  Map<String, dynamic> toMap() {
    return {
      'clientUid': clientUid,
      'clientName': clientName,
      'pickup': {'lat': pickup.latitude, 'lng': pickup.longitude},
      'pickupAddress': pickupAddress,
      'destination': {'lat': destination.latitude, 'lng': destination.longitude},
      'destinationAddress': destinationAddress,
      'vehicleType': vehicleType.name,
      'status': status.firestoreValue,
      'driverUid': driverUid,
      'driverName': driverName,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'recipientInstructions': recipientInstructions,
      'contactRequesterInstead': contactRequesterInstead,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory RideRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final pickupMap = data['pickup'] as Map<String, dynamic>;
    final destinationMap = data['destination'] as Map<String, dynamic>;
    return RideRequest(
      id: doc.id,
      clientUid: data['clientUid'] as String,
      clientName: data['clientName'] as String? ?? '',
      pickup: LatLng((pickupMap['lat'] as num).toDouble(), (pickupMap['lng'] as num).toDouble()),
      pickupAddress: data['pickupAddress'] as String?,
      destination: LatLng(
        (destinationMap['lat'] as num).toDouble(),
        (destinationMap['lng'] as num).toDouble(),
      ),
      destinationAddress: data['destinationAddress'] as String?,
      vehicleType: data['vehicleType'] == 'moto' ? VehicleType.moto : VehicleType.car,
      status: RideStatus.fromFirestoreValue(data['status'] as String? ?? 'searching'),
      driverUid: data['driverUid'] as String?,
      driverName: data['driverName'] as String?,
      recipientName: data['recipientName'] as String?,
      recipientPhone: data['recipientPhone'] as String?,
      recipientInstructions: data['recipientInstructions'] as String?,
      contactRequesterInstead: data['contactRequesterInstead'] as bool? ?? false,
    );
  }
}
