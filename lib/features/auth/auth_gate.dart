import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';

/// Point d'entrée réel de l'application (route `/`).
///
/// Firebase Auth persiste déjà la session sur l'appareil ; le seul problème
/// est que l'app ignorait cet état au démarrage et renvoyait systématiquement
/// vers l'onboarding. Ce widget écoute [FirebaseAuth.authStateChanges] et
/// saute directement à [HomeScreen] si une session est encore valide.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          );
        }
        if (snapshot.data != null) {
          return const HomeScreen();
        }
        return const OnboardingScreen();
      },
    );
  }
}
