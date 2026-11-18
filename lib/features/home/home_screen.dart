import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
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

  // Recréé uniquement sur « Réessayer » : un stream neuf à chaque build
  // relancerait l'abonnement à chaque setState (bandeau e-mail…).
  late Stream<Doc> _userStream =
      UserRepository().watchUser(FirebaseAuth.instance.currentUser!.uid);

  Widget _buildBody(String uid) {
    return StreamBuilder<Doc>(
      stream: _userStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        if (data == null) {
          // Avant : bloc vide => écran noir sans explication quand la base
          // ne répond pas (panne Supabase du 2026-11-18).
          // Clé liée au stream : « Réessayer » repart sur la roue + délai.
          return _ProfileLoading(
            key: ObjectKey(_userStream),
            failed: snapshot.hasError,
            onRetry: () => setState(
              () => _userStream = UserRepository().watchUser(uid),
            ),
          );
        }

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
        return StreamBuilder<Doc>(
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
              return DriverStatusScreen(rejected: false, vehicleType: vehicleType);
            }
            return DriverShell(vehicleType: vehicleType, driverName: user.name);
          },
        );
      },
    );
  }
}

/// Roue de chargement du profil ; passe au message d'erreur si le stream
/// échoue, ou s'il n'a toujours rien renvoyé après [timeout] (une base
/// injoignable peut réessayer en silence sans jamais émettre d'erreur).
class _ProfileLoading extends StatefulWidget {
  const _ProfileLoading({
    super.key,
    required this.failed,
    required this.onRetry,
  });

  static const timeout = Duration(seconds: 15);

  final bool failed;
  final VoidCallback onRetry;

  @override
  State<_ProfileLoading> createState() => _ProfileLoadingState();
}

class _ProfileLoadingState extends State<_ProfileLoading> {
  Timer? _timer;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_ProfileLoading.timeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.failed && !_timedOut) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.textSecondary,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              AppStrings.homeLoadError,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: widget.onRetry,
              child: const Text(AppStrings.homeLoadRetry),
            ),
          ],
        ),
      ),
    );
  }
}
