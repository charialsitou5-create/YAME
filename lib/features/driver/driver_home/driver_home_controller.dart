import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_strings.dart';
import '../../../models/ride_request.dart';
import '../../../repositories/ride_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/dispatch_response_service.dart';
import '../../../services/driver_tracking_service.dart';
import '../../../services/email_verification_service.dart';
import '../../../services/error_reporter.dart';
import '../../../services/payment_service.dart';
import '../../../services/routing_service.dart';

typedef RouteFetcher = Future<RouteResult?> Function({
  required LatLng from,
  required LatLng to,
});

/// Logique d'état de l'écran chauffeur : en ligne/hors ligne, course active,
/// itinéraire, réponse aux offres, progression et fin de course. L'écran ne
/// garde que le rendu ; les messages à afficher passent par [onMessage] et
/// les mouvements de carte par [onMoveMap].
class DriverHomeController extends ChangeNotifier {
  DriverHomeController({
    required this.db,
    required this.uid,
    required this.trackingService,
    this.routeFetcher,
    this.onMessage,
    this.onMoveMap,
    bool Function()? emailBlocks,
  }) : _emailBlocks = emailBlocks ?? (() => emailVerificationBlocksAction());

  final FirebaseFirestore db;
  final String? uid;
  final DriverTrackingService trackingService;
  final RouteFetcher? routeFetcher;
  final void Function(String message)? onMessage;
  final void Function(LatLng point, double zoom)? onMoveMap;
  final bool Function() _emailBlocks;

  bool online = false;
  String? activeRideId;
  RouteResult? route;
  LatLng? _routeOrigin;
  DateTime? _routeFetchedAt;
  bool _fetchingRoute = false;
  bool _hasFix = false;
  bool _disposed = false;

  bool get disposed => _disposed;

  void init() {
    _recoverActiveRide();
    trackingService.position.addListener(_followFirstFix);
    // Position réelle dès l'ouverture (même hors ligne).
    recenterOnMe(silent: true);
  }

  void _resetRoute() {
    route = null;
    _routeOrigin = null;
    _routeFetchedAt = null;
  }

  /// Recalcule l'itinéraire réel (OSRM) au plus une fois toutes les 15s, ou
  /// si le chauffeur s'est déplacé de plus de 30m. Best-effort.
  void maybeFetchRoute(LatLng origin, LatLng destination) {
    if (_fetchingRoute) return;
    final now = DateTime.now();
    final stale =
        _routeFetchedAt == null ||
        now.difference(_routeFetchedAt!) > const Duration(seconds: 15);
    final moved =
        _routeOrigin == null ||
        Geolocator.distanceBetween(
              origin.latitude,
              origin.longitude,
              _routeOrigin!.latitude,
              _routeOrigin!.longitude,
            ) >
            30;
    if (!stale && !moved) return;

    _fetchingRoute = true;
    final fetcher = routeFetcher ?? RoutingService.fetchRoute;
    fetcher(from: origin, to: destination).then((result) {
      _fetchingRoute = false;
      if (_disposed || result == null) return;
      route = result;
      _routeOrigin = origin;
      _routeFetchedAt = DateTime.now();
      notifyListeners();
    });
  }

  void _followFirstFix() {
    final p = trackingService.position.value;
    if (p == null || _hasFix || _disposed) return;
    _hasFix = true;
    try {
      onMoveMap?.call(p, 15);
    } catch (e, st) {
      ErrorReporter.report(e, st, context: 'driver_home.move_map_15');
    }
  }

  /// Bouton GPS : relit la vraie position et recentre la carte.
  Future<void> recenterOnMe({bool silent = false}) async {
    final p = await trackingService.locateNow();
    if (_disposed) return;
    if (p == null) {
      if (!silent) onMessage?.call(AppStrings.driverLocateFailed);
      return;
    }
    _hasFix = true;
    try {
      onMoveMap?.call(p, 16);
    } catch (e, st) {
      ErrorReporter.report(e, st, context: 'driver_home.move_map_16');
    }
  }

  Future<void> _recoverActiveRide() async {
    final id = uid;
    if (id == null) return;
    final doc = await UserRepository(db).getUser(id);
    final activeId = doc.data()?['driverActiveRideId'] as String?;
    final wasOnline = doc.data()?['driverOnline'] as bool? ?? false;
    if (_disposed) return;
    if (activeId != null) {
      activeRideId = activeId;
      notifyListeners();
    }
    // Le statut en ligne est persisté (voir toggleOnline) : on relance le
    // suivi GPS pour rester cohérent avec l'affichage.
    if (wasOnline) {
      online = true;
      notifyListeners();
      trackingService.startTracking();
    }
  }

  void toggleOnline(bool value) {
    if (value && _emailBlocks()) {
      onMessage?.call(AppStrings.emailVerifyRequired);
      return;
    }
    online = value;
    notifyListeners();
    final id = uid;
    if (id != null) {
      UserRepository(db).updateUser(id, {'driverOnline': value});
    }
    if (value) {
      trackingService.startTracking();
    } else {
      trackingService.stopTracking();
    }
  }

  Future<void> respondToOffer(RideRequest request, bool accept) async {
    final id = request.id;
    if (id == null) return;
    try {
      await DispatchResponseService.respond(rideId: id, accept: accept);
      if (_disposed || !accept) return;
      await _waitForAssignmentConfirmation(id);
    } catch (_) {
      if (_disposed) return;
      onMessage?.call(AppStrings.driverRequestTaken);
    }
  }

  /// Un 200 de `/api/rides/respond` signifie seulement que le hook serveur a
  /// été relancé : on attend la confirmation réelle (accepted + driverUid)
  /// sur ride_requests/{id}, avec un délai de 15s.
  Future<void> _waitForAssignmentConfirmation(String id) async {
    final completer = Completer<bool>();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subscription;
    Timer? timeoutTimer;

    subscription = RideRepository(db).watchRide(id).listen((snapshot) {
      final data = snapshot.data();
      if (data != null &&
          data['status'] == 'accepted' &&
          data['driverUid'] == uid) {
        if (!completer.isCompleted) completer.complete(true);
      }
    });

    timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) completer.complete(false);
    });

    final confirmed = await completer.future;
    await subscription.cancel();
    timeoutTimer.cancel();

    if (_disposed) return;
    if (confirmed) {
      activeRideId = id;
      _resetRoute();
      notifyListeners();
    } else {
      onMessage?.call(AppStrings.driverRequestTaken);
    }
  }

  /// Le client a annulé pendant la course : libère le chauffeur.
  Future<void> releaseCancelledRide() async {
    final id = activeRideId;
    if (id == null) return;
    activeRideId = null;
    _resetRoute();
    notifyListeners();
    if (uid != null) {
      await RideRepository(db).releaseDriver(uid!);
    }
    if (_disposed) return;
    onMessage?.call(AppStrings.driverRideCancelledByClient);
  }

  /// La course active n'existe plus : retour à l'état disponible (local).
  void clearActiveRide() {
    activeRideId = null;
    _resetRoute();
    notifyListeners();
  }

  Future<void> endRide(RideStatus newStatus) async {
    final id = activeRideId;
    if (id == null) return;
    await RideRepository(db)
        .finishRide(rideId: id, status: newStatus, driverUid: uid);
    if (newStatus == RideStatus.completed) {
      try {
        await PaymentService.chargeCommission(rideId: id);
      } catch (_) {
        if (!_disposed) onMessage?.call(AppStrings.driverCommissionError);
      }
    }
    if (_disposed) return;
    activeRideId = null;
    _resetRoute();
    notifyListeners();
  }

  /// Fait avancer la course d'une étape (accepted → arrived → inProgress) ;
  /// l'ancien itinéraire est effacé pour être recalculé vers la bonne cible.
  Future<void> advanceRide(RideStatus newStatus) async {
    final id = activeRideId;
    if (id == null) return;
    await RideRepository(db)
        .updateRide(id, {'status': newStatus.firestoreValue});
    if (_disposed) return;
    _resetRoute();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    trackingService.position.removeListener(_followFirstFix);
    trackingService.stopTracking();
    super.dispose();
  }
}
