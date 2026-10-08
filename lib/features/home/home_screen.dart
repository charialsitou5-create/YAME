import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/email_verification_banner.dart';
import '../../models/app_mode.dart';
import '../../models/moderation.dart';
import '../../services/email_verification_service.dart';
import '../../models/app_user.dart';
import '../../services/notification_service.dart';
import '../driver/driver_intro_screen.dart';
import '../driver/driver_shell.dart';
import '../driver/driver_status_screen.dart';
import 'client_shell.dart';
import '../../repositories/driver_repository.dart';
import '../../repositories/user_repository.dart';

/// Aiguille vers l'écran de réservation (client) ou l'écran chauffeur,
/// selon le rôle du profil chargé depuis Firestore.
///
/// Point de passage unique de toute session connectée (démarrage à froid
/// via AuthGate, ou connexion/inscription fraîche — les deux amènent ici,
/// jamais par AuthGate une deuxième fois) : c'est donc l'endroit choisi
/// pour enregistrer le token FCM une seule fois par session, plutôt que de
/// dupliquer l'appel dans chaque écran de connexion/inscription.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _emailSource = FirebaseEmailVerificationSource();
  late bool _bannerVisible = _emailSource.needsVerification;

  @override
  void initState() {
    super.initState();
    NotificationService().initializeAndRegisterToken();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    // Structure stable (Column) : le bandeau apparaît/disparaît sans recréer
    // l'état des shells en dessous.
    return Column(
      children: [
        if (_bannerVisible)
          SafeArea(
            bottom: false,
            child: EmailVerificationBanner(
              source: _emailSource,
              onVisibilityChanged: (v) => setState(() => _bannerVisible = v),
            ),
          ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: _bannerVisible,
            child: _buildBody(uid),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: UserRepository().watchUser(uid),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        if (data == null) return const SizedBox.shrink();

        final user = AppUser.fromMap(uid, data);
        if (user.activeMode == AppMode.client) {
          return ClientShell(name: user.name);
        }

        final vehicleType = user.driverVehicleType;
        if (vehicleType == null) {
          // Filet de sécurité : activeMode ne devrait jamais être `driver`
          // sans qu'un véhicule ait été choisi (voir signup_screen.dart /
          // ProfilScreen).
          return ClientShell(name: user.name);
        }
        if (!user.vehicleRegistered) {
          return DriverIntroScreen(vehicleType: vehicleType);
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: DriverRepository().watchProfile(uid),
          builder: (context, profileSnapshot) {
            final status =
                profileSnapshot.data?.data()?['status'] as String? ??
                'pending_verification';
            final suspension = ModerationState.forDriver(profileSnapshot.data?.data());
            if (suspension != null) {
              return DriverStatusScreen(rejected: false, suspension: suspension);
            }
            if (status == 'rejected') {
              return const DriverStatusScreen(rejected: true);
            }
            if (status != 'approved') {
              return const DriverStatusScreen(rejected: false);
            }
            return DriverShell(vehicleType: vehicleType, driverName: user.name);
          },
        );
      },
    );
  }
}
