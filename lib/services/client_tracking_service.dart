import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import './error_reporter.dart';
import '../repositories/user_repository.dart';

/// Service de suivi GPS en arrière-plan côté client, actif pendant qu'une
/// course est en cours (demandée → résolue) : diffuse la position vers
/// Firestore `users/{uid}/location/current`, symétrique de
/// `DriverTrackingService`. Sert à afficher le client qui se déplace sur sa
/// propre carte, et — une fois un chauffeur affecté (`activeDriverUid`, posé
/// par yame-admin) — à ce que ce chauffeur voie où se trouve réellement le
/// client plutôt qu'un point de départ figé.
class ClientTrackingService {
  StreamSubscription<Position>? _positionStreamSubscription;

  /// Démarre le suivi GPS et envoie la position actuelle vers Firestore
  /// `users/{uid}/location/current`.
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

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _updateClientLocationInFirestore(uid, position);
    });
  }

  Future<void> _updateClientLocationInFirestore(String uid, Position position) async {
    try {
      await UserRepository().clientLocationRef(uid)
          .set({
        'lat': position.latitude,
        'lng': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      ErrorReporter.report(e, st, context: 'client_tracking.publish_location');
      }
  }

  /// Arrête le suivi GPS et révoque l'accès du chauffeur affecté (le cas
  /// échéant) à la position — appelé à la résolution de la course
  /// (terminée/annulée/aucun chauffeur trouvé), jamais laissé ouvert
  /// indéfiniment.
  Future<void> stopTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await UserRepository().clientLocationRef(uid)
          .set({'activeDriverUid': FieldValue.delete()}, SetOptions(merge: true));
    } catch (e, st) {
      ErrorReporter.report(e, st, context: 'client_tracking.clear_active_driver');
      }
  }
}
