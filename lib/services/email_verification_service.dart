import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_config.dart';

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

/// Porte « e-mail vérifié » à appeler avant commander / passer en ligne.
/// Sans effet tant que [AppConfig.requireVerifiedEmail] est `false`.
bool emailVerificationBlocksAction([EmailVerificationSource? source]) {
  if (!AppConfig.requireVerifiedEmail) return false;
  return emailGateBlocks(
    requireVerifiedEmail: true,
    needsVerification: (source ?? FirebaseEmailVerificationSource()).needsVerification,
  );
}
