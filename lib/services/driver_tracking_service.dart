import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import './error_reporter.dart';

/// Service de suivi GPS en arrière-plan et de diffusion de la position
/// du chauffeur vers Firestore en temps réel.
class DriverTrackingService {
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _heartbeat;

  /// Dernière position connue, relayée à l'UI pour recentrer la carte.
  final ValueNotifier<LatLng?> position = ValueNotifier<LatLng?>(null);

  /// Relocalise le chauffeur maintenant : lit une position GPS fraîche,
  /// l'écrit dans Firestore et la publie sur [position]. Retourne `null` si
  /// la permission est refusée ou le GPS indisponible.
  Future<LatLng?> locateNow() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await _updateDriverLocationInFirestore(uid, pos);
      return position.value;
    } catch (_) {
      return null;
    }
  }

  /// Démarre le suivi GPS et envoie la position actuelle vers Firestore `driver_profiles/{uid}`
  Future<void> startTracking() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // Configuration du flux de localisation (mise à jour tous les 10 mètres)
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    // Sans position initiale, un chauffeur immobile n'écrivait rien (le flux
    // n'émet qu'après 10 m de déplacement) : sa position restait absente ou
    // périmée et le dispatch l'écartait. On publie donc tout de suite, puis
    // toutes les 30 s tant qu'il est en ligne.
    unawaited(locateNow());
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(locateNow()),
    );

    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _updateDriverLocationInFirestore(uid, position);
    });
  }

  /// Met à jour la position GPS du chauffeur dans sa sous-collection privée
  /// `driver_profiles/{uid}/location/current` (jamais dans la fiche
  /// principale, lisible par tout utilisateur connecté).
  Future<void> _updateDriverLocationInFirestore(String uid, Position position_) async {
    position.value = LatLng(position_.latitude, position_.longitude);
    try {
      await FirebaseFirestore.instance
          .collection('driver_profiles')
          .doc(uid)
          .collection('location')
          .doc('current')
          .set({
        'lat': position_.latitude,
        'lng': position_.longitude,
        'heading': position_.heading,
        'speed': position_.speed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      ErrorReporter.report(e, st, context: 'driver_tracking.publish_location');
      }
  }

  /// Arrête le suivi GPS du chauffeur
  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _heartbeat?.cancel();
    _heartbeat = null;
  }
}
