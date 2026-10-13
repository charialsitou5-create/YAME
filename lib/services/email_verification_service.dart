import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_config.dart';
import 'event_logger.dart';

/// Un compte doit vérifier son e-mail seulement s'il s'est inscrit avec un
/// mot de passe et que l'adresse n'est pas encore confirmée. Google /
/// Facebook fournissent déjà une adresse vérifiée.
bool emailNeedsVerification({
  required bool emailVerified,
  required Iterable<String> providerIds,
}) =>
    !emailVerified && providerIds.contains('password');

/// `true` si l'action (commander, passer en ligne) doit être refusée.
bool emailGateBlocks({
  required bool requireVerifiedEmail,
  required bool needsVerification,
}) =>
    requireVerifiedEmail && needsVerification;

/// Accès à l'état de vérification de l'e-mail (abstrait pour les tests).
abstract class EmailVerificationSource {
  bool get needsVerification;
  Future<void> resend();

  /// Recharge l'utilisateur depuis Firebase ; renvoie `true` si vérifié.
  Future<bool> reloadAndCheck();
}

class FirebaseEmailVerificationSource implements EmailVerificationSource {
  FirebaseEmailVerificationSource([FirebaseAuth? auth]) : _auth = auth;

  final FirebaseAuth? _auth;
  FirebaseAuth get _a => _auth ?? FirebaseAuth.instance;

  @override
  bool get needsVerification {
    final user = _a.currentUser;
    if (user == null) return false;
    return emailNeedsVerification(
      emailVerified: user.emailVerified,
      providerIds: user.providerData.map((p) => p.providerId),
    );
  }

  @override
  Future<void> resend() async => _a.currentUser?.sendEmailVerification();

  @override
  Future<bool> reloadAndCheck() async {
    await _a.currentUser?.reload();
    return !needsVerification;
  }
}

/// Réglage d'exigence de l'e-mail vérifié, piloté depuis le panneau admin
/// (document `app_config/auth`). Tant qu'il n'a pas été lu (hors ligne,
/// pas encore connecté), on retombe sur [AppConfig.requireVerifiedEmail].
class AuthPolicy {
  AuthPolicy._();

  static bool? _remote;

  static bool get requireVerifiedEmail => _remote ?? AppConfig.requireVerifiedEmail;

  /// À appeler une fois connecté (les règles Firestore exigent une session).
  static Future<void> refresh([FirebaseFirestore? firestore]) async {
    try {
      final snap = await (firestore ?? FirebaseFirestore.instance)
          .collection('app_config')
          .doc('auth')
          .get();
      _remote = snap.data()?['requireVerifiedEmail'] == true;
    } catch (_) {
      // On garde la dernière valeur connue.
    }
  }

  static void setForTest(bool? value) => _remote = value;
}

/// Porte « e-mail vérifié » à appeler avant commander / passer en ligne.
/// Sans effet tant que l'exigence n'est pas activée (admin ou [AppConfig]).
bool emailVerificationBlocksAction([EmailVerificationSource? source]) {
  if (!AuthPolicy.requireVerifiedEmail) return false;
  final blocked = emailGateBlocks(
    requireVerifiedEmail: true,
    needsVerification: (source ?? FirebaseEmailVerificationSource()).needsVerification,
  );
  if (blocked) AppEventLogger.log('email_verification_blocked');
  return blocked;
}
