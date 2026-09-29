import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../services/notification_service.dart';

/// Réglages de compte — volontairement minimal : seules les Notifications
/// sont un contrôle réel pour l'instant. Désactiver retire le token FCM du
/// profil Firestore, donc plus rien à envoyer côté dispatch (voir
/// `yame-admin/lib/dispatch/workflow.ts`, qui n'appelle `adminMessaging()`
/// que si `fcmToken` existe). Langue et Confidentialité n'ont pas encore de
/// contenu réel derrière, donc affichées désactivées plutôt que simulées.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profileSettings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  if (uid != null) _NotificationsToggleRow(uid: uid),
                  const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
                  const _ComingSoonRow(
                    icon: Icons.language_rounded,
                    title: AppStrings.settingsLanguageTitle,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
                  const _ComingSoonRow(
                    icon: Icons.privacy_tip_outlined,
                    title: AppStrings.settingsPrivacyTitle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsToggleRow extends StatefulWidget {
  const _NotificationsToggleRow({required this.uid});

  final String uid;

  @override
  State<_NotificationsToggleRow> createState() => _NotificationsToggleRowState();
}

class _NotificationsToggleRowState extends State<_NotificationsToggleRow> {
  bool _busy = false;

  Future<void> _toggle(bool enabled) async {
    setState(() => _busy = true);
    try {
      if (enabled) {
        await NotificationService().initializeAndRegisterToken();
      } else {
        await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
          'fcmToken': FieldValue.delete(),
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
      builder: (context, snapshot) {
        final enabled = snapshot.data?.data()?['fcmToken'] != null;
        return ListTile(
          leading: const Icon(Icons.notifications_none_rounded),
          title: const Text(AppStrings.settingsNotificationsTitle),
          subtitle: const Text(AppStrings.settingsNotificationsSubtitle),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch(
                  value: enabled,
                  activeThumbColor: AppColors.accent,
                  onChanged: _toggle,
                ),
        );
      },
    );
  }
}

class _ComingSoonRow extends StatelessWidget {
  const _ComingSoonRow({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: false,
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title),
      trailing: Text(
        AppStrings.socialAuthComingSoon,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }
}
