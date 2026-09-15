import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';

/// Service gérant l'enregistrement des tokens Push FCM et la réception
/// des notifications en direct sur les téléphones clients et chauffeurs.
class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  bool _foregroundListenerAttached = false;

  Future<void> _writeToken(String uid, String token) {
    return FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmToken': token,
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Demande les autorisations et enregistre le token FCM dans le profil Firestore
  Future<void> initializeAndRegisterToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Demande de permission pour les notifications (iOS & Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _writeToken(user.uid, token);
      }
    }

    // Le token FCM tourne périodiquement (réinstall, données effacées, etc.)
    // — sans ce listener, un token expiré resterait indéfiniment dans
    // Firestore et le dispatch enverrait des pushs dans le vide.
    _fcm.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) _writeToken(uid, token);
    });

    // Écoute en premier plan (Foreground Notifications) — l'app ne reçoit
    // aucun affichage système automatique pendant qu'elle est ouverte,
    // contrairement à l'arrière-plan/fermée où FCM affiche seul la
    // notification native. On ne l'attache qu'une fois par processus :
    // sinon chaque nouvelle session (déconnexion/reconnexion) empilerait
    // un listener supplémentaire et déclencherait plusieurs SnackBars pour
    // un seul message.
    if (_foregroundListenerAttached) return;
    _foregroundListenerAttached = true;
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      final messengerState = scaffoldMessengerKey.currentState;
      if (messengerState == null) return;

      HapticFeedback.mediumImpact();
      messengerState.showSnackBar(
        SnackBar(
          content: Text(
            notification.body?.isNotEmpty == true
                ? notification.body!
                : notification.title ?? '',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    });
  }
}
