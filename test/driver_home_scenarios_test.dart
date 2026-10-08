import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:yame/core/constants/app_strings.dart';
import 'package:yame/core/fare.dart';
import 'package:yame/features/driver/driver_home_screen.dart';
import 'package:yame/models/vehicle_type.dart';
import 'package:yame/services/driver_tracking_service.dart';
import 'package:yame/services/routing_service.dart';

class _NoGps extends DriverTrackingService {
  @override
  Future<void> startTracking() async {}
  @override
  void stopTracking() {}
  @override
  Future<LatLng?> locateNow() async => null;
}

const _uid = 'drv1';

Map<String, dynamic> _ride({String status = 'searching', bool offered = true, int? price}) => {
      'clientUid': 'cli1',
      'clientName': 'Jean-Baptiste Mouanda-Nkounkou',
      'pickup': {'lat': -4.78, 'lng': 11.86},
      'destination': {'lat': -4.80, 'lng': 11.88},
      'pickupAddress': 'Avenue Charles de Gaulle, quartier Centre-ville, Pointe-Noire',
      'destinationAddress': 'Aéroport Agostinho-Neto, terminal arrivées, Pointe-Noire',
      'vehicleType': 'car',
      'status': status,
      'driverUid': status == 'accepted' ? _uid : null,
      if (offered) 'offeredUid': _uid,
      if (offered) 'offerExpiresAt': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      'price': ?price,
    };

Future<FakeFirebaseFirestore> _db({
  int balance = 5000,
  bool online = true,
  String? activeRide,
  Map<String, dynamic>? ride,
  LatLng? driverLocation,
}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc(_uid).set({
    'driverOnline': online,
    'driverActiveRideId': activeRide,
  });
  await db.collection('driver_profiles').doc(_uid).collection('wallet').doc('current').set({'balance': balance});
  if (driverLocation != null) {
    await db.collection('driver_profiles').doc(_uid).collection('location').doc('current').set({
      'lat': driverLocation.latitude,
      'lng': driverLocation.longitude,
    });
  }
  if (ride != null) await db.collection('ride_requests').doc('r1').set(ride);
  return db;
}

Future<void> _pump(WidgetTester t, FakeFirebaseFirestore db, Size size, double scale) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: DriverHomeScreen(
      vehicleType: VehicleType.car,
      driverName: 'Test',
      firestore: db,
      uid: _uid,
      trackingService: _NoGps(),
      // Jamais de vrai appel réseau OSRM dans les tests widgets.
      routeFetcher: ({required from, required to}) async => null,
    ),
  ));
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _see(WidgetTester t, String text) async {
  await t.scrollUntilVisible(
    find.text(text),
    150,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
}

void main() {
  final sizes = [const Size(360, 640), const Size(320, 480), const Size(411, 890)];
  final scales = [1.0, 1.3, 1.6];

  for (final size in sizes) {
    for (final scale in scales) {
      final tag = '${size.width.toInt()}x${size.height.toInt()} x$scale';

      testWidgets('offre de course $tag', (t) async {
        final db = await _db(ride: _ride());
        await _pump(t, db, size, scale);
        await _see(t, AppStrings.driverAccept);
        expect(find.text(AppStrings.driverAccept), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('course active $tag', (t) async {
        final db = await _db(activeRide: 'r1', ride: _ride(status: 'accepted', offered: false));
        await _pump(t, db, size, scale);
        await _see(t, AppStrings.driverCancelRide);
        expect(find.text(AppStrings.driverCancelRide), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('en ligne sans demande $tag', (t) async {
        final db = await _db();
        await _pump(t, db, size, scale);
        await _see(t, AppStrings.driverNoRequests);
        expect(find.text(AppStrings.driverNoRequests), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('hors ligne $tag', (t) async {
        final db = await _db(online: false);
        await _pump(t, db, size, scale);
        expect(t.takeException(), isNull);
      });

      testWidgets('solde épuisé $tag', (t) async {
        final db = await _db(balance: 0, online: false);
        await _pump(t, db, size, scale);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('annulation : confirmation puis course annulée', (t) async {
    final db = await _db(activeRide: 'r1', ride: _ride(status: 'accepted', offered: false));
    await _pump(t, db, const Size(360, 640), 1.3);
    final cancel = find.text(AppStrings.driverCancelRide);
    await _see(t, AppStrings.driverCancelRide);
    await t.ensureVisible(cancel);
    await t.pump();
    await t.tap(cancel);
    await t.pumpAndSettle();
    expect(find.text(AppStrings.driverCancelConfirmTitle), findsOneWidget);

    // « Non, continuer » ne change rien
    await t.tap(find.text(AppStrings.driverCancelConfirmKeep));
    await t.pumpAndSettle();
    expect((await db.collection('ride_requests').doc('r1').get()).data()!['status'], 'accepted');

    // « Oui, annuler » annule
    await _see(t, AppStrings.driverCancelRide);
    await t.ensureVisible(cancel);
    await t.pump();
    await t.tap(cancel);
    await t.pumpAndSettle();
    await t.tap(find.text(AppStrings.driverCancelConfirmYes));
    await t.pumpAndSettle();
    expect((await db.collection('ride_requests').doc('r1').get()).data()!['status'], 'cancelled');
    expect((await db.collection('users').doc(_uid).get()).data()!['driverActiveRideId'], isNull);
    expect(find.text(AppStrings.driverCancelRide), findsNothing);
  });

  testWidgets('offre de course affiche le prix quoté au client', (t) async {
    final db = await _db(ride: _ride(price: 2500));
    await _pump(t, db, const Size(360, 640), 1.3);
    await _see(t, '${AppStrings.driverOfferPrice} — ${formatFcfa(2500)} FCFA');
    expect(find.text('${AppStrings.driverOfferPrice} — ${formatFcfa(2500)} FCFA'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('offre de course sans prix (course créée avant ce champ) ne casse pas', (t) async {
    final db = await _db(ride: _ride());
    await _pump(t, db, const Size(360, 640), 1.3);
    await _see(t, AppStrings.driverAccept);
    expect(find.textContaining(AppStrings.driverOfferPrice), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('course active affiche le temps d\'arrivée estimé une fois l\'itinéraire reçu', (t) async {
    final db = await _db(
      activeRide: 'r1',
      ride: _ride(status: 'accepted', offered: false),
      driverLocation: const LatLng(-4.79, 11.87),
    );

    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: DriverHomeScreen(
        vehicleType: VehicleType.car,
        driverName: 'Test',
        firestore: db,
        uid: _uid,
        trackingService: _NoGps(),
        routeFetcher: ({required from, required to}) async => const RouteResult(
          polyline: [LatLng(-4.79, 11.87), LatLng(-4.78, 11.86)],
          distanceMeters: 1500,
          durationSeconds: 240,
        ),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }

    await _see(t, '${AppStrings.driverEtaToPickupPrefix} ${formatEta(const Duration(seconds: 240))}');
    expect(
      find.text('${AppStrings.driverEtaToPickupPrefix} ${formatEta(const Duration(seconds: 240))}'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'course active progresse accepted -> arrived -> inProgress -> completed sans sauter d\'étape',
    (t) async {
      final db = await _db(activeRide: 'r1', ride: _ride(status: 'accepted', offered: false));
      await _pump(t, db, const Size(360, 640), 1.3);

      // accepted : "Je suis arrivé" est visible, "Terminer" ne l'est pas encore.
      await _see(t, AppStrings.driverMarkArrived);
      expect(find.text(AppStrings.driverMarkArrived), findsOneWidget);
      expect(find.text(AppStrings.driverComplete), findsNothing);

      final markArrived = find.text(AppStrings.driverMarkArrived);
      await t.ensureVisible(markArrived);
      await t.pump();
      await t.tap(markArrived);
      await t.pumpAndSettle();
      expect((await db.collection('ride_requests').doc('r1').get()).data()!['status'], 'arrived');

      // arrived : "Client à bord" est visible.
      await _see(t, AppStrings.driverStartRide);
      expect(find.text(AppStrings.driverStartRide), findsOneWidget);

      final startRide = find.text(AppStrings.driverStartRide);
      await t.ensureVisible(startRide);
      await t.pump();
      await t.tap(startRide);
      await t.pumpAndSettle();
      expect((await db.collection('ride_requests').doc('r1').get()).data()!['status'], 'inProgress');

      // inProgress : "Terminer la course" (comportement historique) est visible.
      await _see(t, AppStrings.driverComplete);
      expect(find.text(AppStrings.driverComplete), findsOneWidget);

      final complete = find.text(AppStrings.driverComplete);
      await t.ensureVisible(complete);
      await t.pump();
      await t.tap(complete);
      await t.pumpAndSettle();
      expect((await db.collection('ride_requests').doc('r1').get()).data()!['status'], 'completed');
      expect(find.text(AppStrings.driverComplete), findsNothing);
    },
  );
}
