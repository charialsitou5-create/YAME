import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../routes/app_routes.dart';
import '../booking/booking_screen.dart';

/// Écran d'accueil : réservation de course pour un client, placeholder
/// provisoire pour un chauffeur (ce volet n'est pas encore construit).
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

    if (uid == null) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const _DriverPlaceholder(userName: null),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final user = data != null ? AppUser.fromMap(uid, data) : null;

        if (user != null && user.role == UserRole.client) {
          return const BookingScreen();
        }

        return Scaffold(
          appBar: _buildAppBar(context),
          body: _DriverPlaceholder(userName: user?.name),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text(AppStrings.appName),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded),
          tooltip: AppStrings.logout,
          onPressed: () => _logout(context),
        ),
      ],
    );
  }
}

class _DriverPlaceholder extends StatelessWidget {
  const _DriverPlaceholder({required this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_taxi_outlined, size: 64, color: AppColors.textSecondary),
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
        ),
      ),
    );
  }
}
