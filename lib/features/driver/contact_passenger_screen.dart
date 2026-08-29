import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ride_request.dart';

/// Coordonnées du passager à contacter pour une course : soit la personne
/// pour qui la course a été commandée (destinataire), soit le demandeur
/// lui-même (client) — selon `RideRequest.contactRequesterInstead`.
///
/// Écran clair, comme le paiement et la notation, distinct du thème sombre
/// du reste de l'application.
class ContactPassengerScreen extends StatefulWidget {
  const ContactPassengerScreen({super.key, required this.ride});

  final RideRequest ride;

  @override
  State<ContactPassengerScreen> createState() => _ContactPassengerScreenState();
}

class _ContactPassengerScreenState extends State<ContactPassengerScreen> {
  bool get _showRecipient => widget.ride.isForSomeoneElse && !widget.ride.contactRequesterInstead;

  late final String _name;
  String? _phone;
  bool _loadingPhone = false;

  @override
  void initState() {
    super.initState();
    if (_showRecipient) {
      _name = widget.ride.recipientName!;
      _phone = widget.ride.recipientPhone;
    } else {
      _name = widget.ride.clientName.isNotEmpty ? widget.ride.clientName : AppStrings.driverClient;
      _loadRequesterPhone();
    }
  }

  Future<void> _loadRequesterPhone() async {
    setState(() => _loadingPhone = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.ride.clientUid)
          .get();
      if (!mounted) return;
      setState(() => _phone = doc.data()?['phone'] as String?);
    } finally {
      if (mounted) setState(() => _loadingPhone = false);
    }
  }

  Future<void> _call() async {
    final phone = _phone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.contactPassengerCallError)));
    }
  }

  Future<void> _message() async {
    final phone = _phone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'sms', path: phone.replaceAll(' ', ''));
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.contactPassengerMessageError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final notice = ride.isForSomeoneElse
        ? (_showRecipient
              ? AppStrings.contactPassengerNoticeRecipient
              : AppStrings.contactPassengerNoticeRequester)
        : null;
    final instructions = _showRecipient ? ride.recipientInstructions : null;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        title: const Text(
          AppStrings.contactPassengerTitle,
          style: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.lightBorder),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.contactPassengerLabel,
                      style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _name,
                      style: const TextStyle(
                        color: AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_loadingPhone)
                      const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      )
                    else if (_phone == null || _phone!.isEmpty)
                      const Text(
                        AppStrings.contactPassengerNoPhone,
                        style: TextStyle(color: AppColors.lightTextSecondary),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _phone!,
                              style: const TextStyle(
                                color: AppColors.lightTextPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          _CircleIconButton(
                            icon: Icons.call_rounded,
                            color: AppColors.success,
                            tooltip: AppStrings.contactPassengerCall,
                            onTap: _call,
                          ),
                          const SizedBox(width: 12),
                          _CircleIconButton(
                            icon: Icons.sms_rounded,
                            color: const Color(0xFF3B82F6),
                            tooltip: AppStrings.contactPassengerMessage,
                            onTap: _message,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (instructions != null && instructions.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  AppStrings.contactPassengerInstructions,
                  style: TextStyle(
                    color: AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  instructions,
                  style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 14),
                ),
              ],
              if (notice != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          notice,
                          style: const TextStyle(color: AppColors.lightTextPrimary, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
