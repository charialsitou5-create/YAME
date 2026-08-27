import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/chat_message.dart';
import '../../models/ride_request.dart';

/// Conversation avec le chauffeur assigné à [ride] : infos chauffeur,
/// statut de la course, messages en direct, envoi de texte et de position.
class RideChatScreen extends StatefulWidget {
  const RideChatScreen({super.key, required this.ride, required this.onViewRide});

  final RideRequest ride;
  final VoidCallback onViewRide;

  @override
  State<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends State<RideChatScreen> {
  final _textController = TextEditingController();
  final _geocoding = Geocoding();
  bool _sendingLocation = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _messages => FirebaseFirestore.instance
      .collection('ride_requests')
      .doc(widget.ride.id)
      .collection('messages');

  void _showComingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.socialAuthComingSoon)));
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (text.isEmpty || uid == null) return;

    _textController.clear();
    try {
      await _messages.add(
        ChatMessage(senderUid: uid, type: ChatMessageType.text, text: text).toMap(),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.messagesSendError)));
    }
  }

  Future<void> _sendLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _sendingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw StateError('denied');
      }

      final position = await Geolocator.getCurrentPosition();
      String? address;
      try {
        final placemarks = await _geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          address = [
            p.street,
            p.subLocality,
            p.locality,
          ].whereType<String>().where((part) => part.isNotEmpty).join(', ');
        }
      } catch (_) {
        // adresse facultative : le point envoyé reste utile sans elle.
      }

      await _messages.add(
        ChatMessage(
          senderUid: uid,
          type: ChatMessageType.location,
          locationAddress: (address == null || address.isEmpty) ? null : address,
          latitude: position.latitude,
          longitude: position.longitude,
        ).toMap(),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.messagesLocationError)));
    } finally {
      if (mounted) setState(() => _sendingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(AppStrings.navMessages, style: Theme.of(context).textTheme.headlineMedium),
              ),
              const Icon(Icons.notifications_none_rounded, size: 26),
            ],
          ),
        ),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: widget.ride.driverUid == null
              ? null
              : FirebaseFirestore.instance
                  .collection('driver_profiles')
                  .doc(widget.ride.driverUid)
                  .snapshots(),
          builder: (context, snapshot) {
            final vehicle = snapshot.data?.data();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _DriverCard(
                    driverName: widget.ride.driverName?.isNotEmpty == true
                        ? widget.ride.driverName!
                        : AppStrings.driverClient,
                    model: vehicle?['model'] as String?,
                    color: vehicle?['color'] as String?,
                    plate: vehicle?['plate'] as String?,
                    onCall: _showComingSoon,
                    onTrack: _showComingSoon,
                  ),
                  const SizedBox(height: 12),
                  _AssignedBanner(onViewRide: widget.onViewRide),
                ],
              ),
            );
          },
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _messages.orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const SizedBox.shrink();
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final message = ChatMessage.fromDoc(docs[index]);
                  final isMine = message.senderUid == uid;
                  final showDateSeparator =
                      index == docs.length - 1 ||
                      !_isSameDay(message.timestamp, ChatMessage.fromDoc(docs[index + 1]).timestamp);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDateSeparator) _DateSeparator(timestamp: message.timestamp),
                      _MessageBubble(message: message, isMine: isMine),
                    ],
                  );
                },
              );
            },
          ),
        ),
        _Composer(
          controller: _textController,
          sendingLocation: _sendingLocation,
          onSend: _sendText,
          onAttach: _showComingSoon,
          onTakePhoto: _showComingSoon,
          onSendLocation: _sendLocation,
        ),
      ],
    );
  }
}

bool _isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _timeLabel(DateTime? timestamp) {
  if (timestamp == null) return '';
  return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driverName,
    required this.model,
    required this.color,
    required this.plate,
    required this.onCall,
    required this.onTrack,
  });

  final String driverName;
  final String? model;
  final String? color;
  final String? plate;
  final VoidCallback onCall;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final vehicleLine = [
      if (model != null && model!.isNotEmpty) model,
      if (color != null && color!.isNotEmpty) color,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
            child: Text(
              driverName.isNotEmpty ? driverName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.background,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(AppStrings.messagesDriverSubtitle, style: Theme.of(context).textTheme.bodyMedium),
                if (vehicleLine.isNotEmpty || (plate != null && plate!.isNotEmpty)) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.directions_car_filled_rounded, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          [
                            if (vehicleLine.isNotEmpty) vehicleLine,
                            if (plate != null && plate!.isNotEmpty) plate!,
                          ].join(' • '),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _RoundActionButton(icon: Icons.call_rounded, label: AppStrings.messagesCall, onTap: onCall),
          const SizedBox(width: 10),
          _RoundActionButton(icon: Icons.navigation_rounded, label: AppStrings.messagesTrack, onTap: onTrack),
        ],
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppColors.surfaceElevated,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: AppColors.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _AssignedBanner extends StatelessWidget {
  const _AssignedBanner({required this.onViewRide});

  final VoidCallback onViewRide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.messagesAssignedTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  AppStrings.messagesAssignedBody,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onViewRide,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: const BorderSide(color: AppColors.accent),
              foregroundColor: AppColors.accent,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            child: const Text(AppStrings.messagesViewRideDetails),
          ),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.timestamp});

  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    if (timestamp == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final label = _isSameDay(timestamp, now)
        ? "Aujourd'hui"
        : '${timestamp!.day.toString().padLeft(2, '0')}/${timestamp!.month.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          '$label • ${_timeLabel(timestamp)}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? AppColors.accent : AppColors.surfaceElevated;
    final textColor = isMine ? AppColors.background : AppColors.textPrimary;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.type == ChatMessageType.location) ...[
              Text(
                AppStrings.messagesLocationLabel,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: (isMine ? AppColors.background : AppColors.background).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.location_pin, color: textColor, size: 26),
                    if (message.locationAddress != null) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          message.locationAddress!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textColor, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else
              Text(message.text ?? '', style: TextStyle(color: textColor)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeLabel(message.timestamp),
                  style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 10.5),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.done_all_rounded, size: 13, color: textColor.withValues(alpha: 0.7)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sendingLocation,
    required this.onSend,
    required this.onAttach,
    required this.onTakePhoto,
    required this.onSendLocation,
  });

  final TextEditingController controller;
  final bool sendingLocation;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onTakePhoto;
  final VoidCallback onSendLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _CircleIconButton(icon: Icons.add_rounded, onTap: onAttach),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: const InputDecoration(hintText: AppStrings.messagesComposerHint),
                  ),
                ),
                const SizedBox(width: 10),
                _CircleIconButton(icon: Icons.send_rounded, onTap: onSend, filled: true),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuickActionChip(
                    icon: Icons.camera_alt_outlined,
                    title: AppStrings.messagesTakePhoto,
                    subtitle: AppStrings.messagesTakePhotoSubtitle,
                    onTap: onTakePhoto,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionChip(
                    icon: Icons.location_on_outlined,
                    title: AppStrings.messagesSendLocation,
                    subtitle: AppStrings.messagesSendLocationSubtitle,
                    onTap: sendingLocation ? null : onSendLocation,
                    loading: sendingLocation,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap, this.filled = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.accent : AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: filled ? AppColors.background : AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                    )
                  : Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
