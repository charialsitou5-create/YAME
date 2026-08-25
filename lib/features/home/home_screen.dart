import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/app_user.dart';
import '../../routes/app_routes.dart';

/// Écran d'accueil provisoire — la réservation de course viendra ici.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.onboarding, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: AppStrings.logout,
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: uid == null
              ? _HomeContent(userName: null)
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data();
                    final user = data != null ? AppUser.fromMap(uid, data) : null;
                    return _HomeContent(userName: user?.name);
                  },
                ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.map_outlined, size: 64, color: AppColors.textSecondary),
        const SizedBox(height: 20),
        Text(
          userName != null && userName!.isNotEmpty
              ? '${AppStrings.homeWelcome}, $userName'
              : AppStrings.homeWelcome,
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.homeComingSoon,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
