import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ride_request.dart';
import 'ride_chat_screen.dart';

/// Onglet Messages : affiche la conversation avec le chauffeur assigné à
/// la course en cours du client, ou un état vide si aucune course n'est
/// active.
class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key, required this.onViewRide});

  final VoidCallback onViewRide;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: uid == null
            ? null
            : FirebaseFirestore.instance
                .collection('ride_requests')
                .where('clientUid', isEqualTo: uid)
                .where('status', isEqualTo: RideStatus.accepted.firestoreValue)
                .limit(1)
                .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const _EmptyMessages();
          }

          final ride = RideRequest.fromDoc(docs.first);
          return RideChatScreen(ride: ride, onViewRide: onViewRide);
        },
      ),
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(AppStrings.navMessages, style: Theme.of(context).textTheme.headlineMedium),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 56,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.messagesEmptyTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.messagesEmptyBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
