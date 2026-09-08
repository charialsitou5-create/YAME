import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

/// Service de suivi GPS en arrière-plan et de diffusion de la position
/// du chauffeur vers Firestore en temps réel.
class DriverTrackingService {
  StreamSubscription<Position>? _positionStreamSubscription;

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

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _updateDriverLocationInFirestore(uid, position);
    });
  }

  /// Met à jour la position GPS du chauffeur dans sa sous-collection privée
  /// `driver_profiles/{uid}/location/current` (jamais dans la fiche
  /// principale, lisible par tout utilisateur connecté).
  Future<void> _updateDriverLocationInFirestore(String uid, Position position) async {
    try {
      await FirebaseFirestore.instance
          .collection('driver_profiles')
          .doc(uid)
          .collection('location')
          .doc('current')
          .set({
        'lat': position.latitude,
        'lng': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Arrête le suivi GPS du chauffeur
  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }
}
