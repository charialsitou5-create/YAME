import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Service gérant l'enregistrement des tokens Push FCM et la réception
/// des notifications en direct sur les téléphones clients et chauffeurs.
class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

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
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    // Écoute en premier plan (Foreground Notifications)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Les notifications s'afficheront via les SnackBars ou alertes de l'appli
    });
  }
}
