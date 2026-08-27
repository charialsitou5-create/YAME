import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Notation du chauffeur à la fin d'une course — écran clair, distinct
/// du thème sombre du reste de l'application (comme dans la maquette).
class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final _commentController = TextEditingController();

  int _overall = 0;
  int _punctuality = 0;
  int _driving = 0;
  int _courtesy = 0;
  int _cleanliness = 0;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_overall == 0) {
      setState(() => _error = AppStrings.ratingErrorRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await FirebaseFirestore.instance.collection('ride_requests').doc(widget.rideId).update({
        'rating': _overall,
        if (_commentController.text.trim().isNotEmpty) 'ratingComment': _commentController.text.trim(),
        if (_punctuality > 0) 'ratingPunctuality': _punctuality,
        if (_driving > 0) 'ratingDriving': _driving,
        if (_courtesy > 0) 'ratingCourtesy': _courtesy,
        if (_cleanliness > 0) 'ratingCleanliness': _cleanliness,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.ratingThanks)));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppStrings.ratingSubmitError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
          AppStrings.ratingTitle,
          style: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(false),
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
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 10, top: 6),
                    decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(
                      AppStrings.ratingQuestion,
                      style: const TextStyle(
                        color: AppColors.lightTextPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Center(
                child: _StarRow(
                  value: _overall,
                  size: 44,
                  onChanged: (value) => setState(() {
                    _overall = value;
                    _error = null;
                  }),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Center(child: Text(_error!, style: const TextStyle(color: AppColors.error))),
              ],
              const SizedBox(height: 28),
              const Text(
                AppStrings.ratingCommentLabel,
                style: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _commentController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.lightTextPrimary),
                decoration: InputDecoration(
                  hintText: AppStrings.ratingCommentHint,
                  hintStyle: const TextStyle(color: AppColors.lightTextSecondary),
                  filled: true,
                  fillColor: AppColors.lightSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.lightBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.lightBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _CategoryRow(
                label: AppStrings.ratingPunctuality,
                value: _punctuality,
                onChanged: (v) => setState(() => _punctuality = v),
              ),
              const Divider(color: AppColors.lightBorder, height: 32),
              _CategoryRow(
                label: AppStrings.ratingDriving,
                value: _driving,
                onChanged: (v) => setState(() => _driving = v),
              ),
              const Divider(color: AppColors.lightBorder, height: 32),
              _CategoryRow(
                label: AppStrings.ratingCourtesy,
                value: _courtesy,
                onChanged: (v) => setState(() => _courtesy = v),
              ),
              const Divider(color: AppColors.lightBorder, height: 32),
              _CategoryRow(
                label: AppStrings.ratingCleanliness,
                value: _cleanliness,
                onChanged: (v) => setState(() => _cleanliness = v),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.background,
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                        )
                      : const Text(
                          AppStrings.ratingSubmit,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
                  child: const Text(
                    AppStrings.ratingSkip,
                    style: TextStyle(color: AppColors.lightTextSecondary, fontWeight: FontWeight.w600),
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

class _StarRow extends StatelessWidget {
  const _StarRow({required this.value, required this.onChanged, this.size = 28});

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index < value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: GestureDetector(
            onTap: () => onChanged(index + 1),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: AppColors.accent,
              size: size,
            ),
          ),
        );
      }),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w700, fontSize: 15),
        ),
        _StarRow(value: value, onChanged: onChanged),
      ],
    );
  }
}
