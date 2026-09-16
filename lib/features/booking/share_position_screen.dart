import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Écran plein écran de partage de position — écran clair, comme le
/// paiement et la notation, distinct du thème sombre du reste de l'app.
///
/// Le lien pointe vers la position au moment du partage (instantané) ; il
/// n'y a pas de suivi live ni d'expiration côté serveur, contrairement à
/// la maquette d'origine qui montrait un partage en temps réel sur 24h.
class SharePositionScreen extends StatelessWidget {
  const SharePositionScreen({
    super.key,
    required this.position,
    required this.link,
  });

  final LatLng position;
  final String link;

  Future<void> _openWhatsapp(BuildContext context) async {
    final text = Uri.encodeComponent(
      '${AppStrings.bookingSharePositionMessage} $link',
    );
    final launched = await launchUrl(Uri.parse('https://wa.me/?text=$text'));
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.bookingSharePositionError)),
      );
    }
  }

  Future<void> _openSms(BuildContext context) async {
    final body = Uri.encodeComponent(
      '${AppStrings.bookingSharePositionMessage} $link',
    );
    final launched = await launchUrl(Uri.parse('sms:?body=$body'));
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.bookingSharePositionError)),
      );
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.bookingSharePositionCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        title: const Text(
          AppStrings.sharePositionTitle,
          style: TextStyle(
            color: AppColors.lightTextPrimary,
            fontWeight: FontWeight.w700,
          ),
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
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppStrings.sharePositionSubtitle,
                style: TextStyle(
                  color: AppColors.lightTextPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 220,
                  child: IgnorePointer(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: position,
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.yame.yame',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: position,
                              width: 44,
                              height: 44,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_pin,
                                  color: AppColors.background,
                                  size: 26,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                AppStrings.sharePositionLinkActive,
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.lightBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        link,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.lightTextPrimary,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyLink(context),
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: AppColors.accent,
                        size: 18,
                      ),
                      tooltip: AppStrings.bookingSharePositionCopy,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                AppStrings.sharePositionShareVia,
                style: TextStyle(
                  color: AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ShareOption(
                      icon: Icons.chat_rounded,
                      iconColor: AppColors.success,
                      label: AppStrings.bookingSharePositionWhatsapp,
                      onTap: () => _openWhatsapp(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ShareOption(
                      icon: Icons.sms_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      label: AppStrings.bookingSharePositionSms,
                      onTap: () => _openSms(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ShareOption(
                      icon: Icons.copy_rounded,
                      iconColor: AppColors.lightTextSecondary,
                      label: AppStrings.bookingSharePositionCopy,
                      onTap: () => _copyLink(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppStrings.sharePositionNotice,
                        style: const TextStyle(
                          color: AppColors.lightTextPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    AppStrings.sharePositionClose,
                    style: TextStyle(
                      color: AppColors.lightTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.lightSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.lightBorder),
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
