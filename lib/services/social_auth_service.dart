import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_mode.dart';
import '../models/app_user.dart';
import '../models/vehicle_type.dart';

/// Résultat d'une connexion sociale réussie.
class SocialSignInResult {
  const SocialSignInResult({
    required this.uid,
    required this.needsPhone,
    this.conflictingMode,
  });

  final String uid;

  /// `true` si la fiche `users/{uid}` vient d'être créée sans téléphone —
  /// ni Google ni Facebook ne le communiquent, il doit donc être réclamé
  /// juste après (voir `CompleteProfileScreen`) avant d'entrer dans l'app,
  /// le reste de Yame (contact chauffeur/passager, SMS) en dépend.
  final bool needsPhone;

  /// Non-null si l'appelant a explicitement demandé un rôle (voir
  /// [SocialAuthService.signInWithGoogle]/[signInWithFacebook],
  /// `announceModeConflict: true`, utilisé par les cartes de rôle de
  /// `OnboardingScreen`/`SignupScreen`) et que le compte existait déjà avec
  /// un `activeMode` différent. Le compte n'est PAS basculé automatiquement
  /// — ça reste le rôle exclusif du bouton de bascule dans `ProfilScreen`,
  /// seul endroit qui applique le garde-fou "course en cours" — ce champ ne
  /// sert qu'à prévenir l'utilisateur plutôt que de le rediriger en
  /// silence vers un mode différent de celui qu'il vient de choisir.
  final AppMode? conflictingMode;
}

/// Connexion Google et Facebook via Firebase Auth.
///
/// Nécessite une configuration côté consoles (voir TODO ci-dessous et dans
/// `android/app/src/main/AndroidManifest.xml` / `ios/Runner/Info.plist`) —
/// sans elle, `signInWithGoogle`/`signInWithFacebook` échoueront avec une
/// erreur de configuration (ApiException 10, invalid Facebook App ID, etc).
class SocialAuthService {
  SocialAuthService._();

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _googleInitialized = false;

  static Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize(
      // TODO(yame): Web Client ID (type 3) généré par Firebase pour ce
      // projet. Firebase Console > Authentification > Sign-in method >
      // Google > développer "Configuration SDK Web", ou dans
      // android/app/google-services.json sous client[].oauth_client[] où
      // client_type == 3.
      serverClientId: 'YOUR_FIREBASE_WEB_CLIENT_ID.apps.googleusercontent.com',
    );
    _googleInitialized = true;
  }

  /// Retourne `null` si l'utilisateur annule la connexion (pas une erreur).
  /// [vehicleType] : passé depuis l'écran d'inscription chauffeur, pour que
  /// le compte créé démarre en mode chauffeur plutôt que client — sans
  /// effet sur un compte déjà existant (voir [SocialSignInResult.conflictingMode]).
  /// [announceModeConflict] : `true` quand [vehicleType] reflète un choix
  /// explicite de l'utilisateur (carte de rôle cliquée sur `OnboardingScreen`/
  /// `SignupScreen`) plutôt qu'un simple défaut de `LoginScreen` (qui ne
  /// propose aucun choix de rôle et doit donc toujours valoir `false`).
  static Future<SocialSignInResult?> signInWithGoogle({
    VehicleType? vehicleType,
    bool announceModeConflict = false,
  }) async {
    await _ensureGoogleInitialized();

    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: "Google n'a pas renvoyé de jeton d'identité.",
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    final (createdNew, existingMode) = await _ensureUserDocument(
      userCredential,
      name: account.displayName,
      email: account.email,
      vehicleType: vehicleType,
    );
    return SocialSignInResult(
      uid: userCredential.user!.uid,
      needsPhone: createdNew,
      conflictingMode: _conflictingMode(
        announceModeConflict: announceModeConflict,
        createdNew: createdNew,
        requested: vehicleType == null ? AppMode.client : AppMode.driver,
        existing: existingMode,
      ),
    );
  }

  /// Retourne `null` si l'utilisateur annule la connexion (pas une erreur).
  static Future<SocialSignInResult?> signInWithFacebook({
    VehicleType? vehicleType,
    bool announceModeConflict = false,
  }) async {
    final loginResult = await FacebookAuth.instance.login(
      permissions: const ['email', 'public_profile'],
    );

    if (loginResult.status == LoginStatus.cancelled) return null;
    if (loginResult.status != LoginStatus.success || loginResult.accessToken == null) {
      throw FirebaseAuthException(
        code: 'facebook-login-failed',
        message: loginResult.message ?? 'La connexion Facebook a échoué.',
      );
    }

    final credential = FacebookAuthProvider.credential(loginResult.accessToken!.tokenString);
    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

    final profile = await FacebookAuth.instance.getUserData(fields: 'name,email');
    final (createdNew, existingMode) = await _ensureUserDocument(
      userCredential,
      name: profile['name'] as String?,
      email: profile['email'] as String?,
      vehicleType: vehicleType,
    );
    return SocialSignInResult(
      uid: userCredential.user!.uid,
      needsPhone: createdNew,
      conflictingMode: _conflictingMode(
        announceModeConflict: announceModeConflict,
        createdNew: createdNew,
        requested: vehicleType == null ? AppMode.client : AppMode.driver,
        existing: existingMode,
      ),
    );
  }

  static AppMode? _conflictingMode({
    required bool announceModeConflict,
    required bool createdNew,
    required AppMode requested,
    required AppMode? existing,
  }) {
    if (!announceModeConflict || createdNew || existing == null) return null;
    return existing == requested ? null : existing;
  }

  /// Crée la fiche Firestore `users/{uid}` au premier passage. Renvoie
  /// `(true, null)` si la fiche vient d'être créée (donc sans téléphone),
  /// sinon `(false, <activeMode déjà enregistré>)` — ne modifie jamais
  /// `activeMode` d'un compte existant : seul `ProfilScreen` bascule le
  /// mode d'un compte déjà créé (avec son garde-fou "course en cours").
  static Future<(bool, AppMode?)> _ensureUserDocument(
    UserCredential credential, {
    String? name,
    String? email,
    VehicleType? vehicleType,
  }) async {
    final uid = credential.user!.uid;
    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final doc = await docRef.get();
    if (doc.exists) {
      final activeModeValue = doc.data()?['activeMode'] as String?;
      return (false, AppMode.fromFirestoreValue(activeModeValue ?? ''));
    }

    final user = AppUser(
      uid: uid,
      name: (name ?? credential.user!.displayName ?? '').trim(),
      phone: '',
      email: email ?? credential.user!.email,
      activeMode: vehicleType == null ? AppMode.client : AppMode.driver,
      driverVehicleType: vehicleType,
    );
    await docRef.set(user.toMap());
    return (true, null);
  }

  static Future<void> signOutAll() async {
    await Future.wait([
      FirebaseAuth.instance.signOut(),
      _googleSignIn.signOut(),
      FacebookAuth.instance.logOut(),
    ]);
  }
}
