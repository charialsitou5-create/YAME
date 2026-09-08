import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/driver_vehicle.dart';
import '../../models/user_role.dart';
import '../../models/vehicle_type.dart';

/// Assistant d'inscription du véhicule en 3 étapes : informations,
/// photos, documents — requis avant qu'un chauffeur reçoive des courses.
class VehicleRegistrationWizard extends StatefulWidget {
  const VehicleRegistrationWizard({super.key, required this.role});

  final UserRole role;

  @override
  State<VehicleRegistrationWizard> createState() =>
      _VehicleRegistrationWizardState();
}

class _VehicleRegistrationWizardState extends State<VehicleRegistrationWizard> {
  static final _picker = ImagePicker();

  late final bool _isCar = widget.role.vehicleType == VehicleType.car;
  late final List<String> _photoLabels = _isCar
      ? const [
          AppStrings.wizardPhotoFront,
          AppStrings.wizardPhotoBack,
          AppStrings.wizardPhotoLeft,
          AppStrings.wizardPhotoRight,
        ]
      : const [
          AppStrings.wizardPhotoFront,
          AppStrings.wizardPhotoBack,
          AppStrings.wizardPhotoLeft,
          AppStrings.wizardPhotoRight,
          AppStrings.wizardPhotoOverview,
        ];

  int _step = 0;
  bool _submitting = false;

  final _formKey = GlobalKey<FormState>();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  int? _seats;

  final Map<String, File?> _photos = {};
  File? _registrationCardPhoto;
  File? _licensePhoto;

  @override
  void dispose() {
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<File?> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      return file == null ? null : File(file.path);
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.wizardImagePickError)),
      );
      return null;
    }
  }

  void _goNext() {
    if (_step == 0 && !_formKey.currentState!.validate()) return;
    if (_step < 2) {
      setState(() => _step += 1);
    } else {
      _submit();
    }
  }

  /// `null` en cas d'échec (ex : Firebase Storage pas encore activé sur le
  /// projet) — l'inscription doit pouvoir continuer sans document plutôt
  /// que d'échouer entièrement à cause d'un problème d'upload.
  Future<String?> _uploadDoc(String uid, String path, File file) async {
    try {
      final ref = FirebaseStorage.instance.ref('driver_documents/$uid/$path');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);
    try {
      final photoUrls = <String, String>{};
      for (final entry in _photos.entries) {
        final file = entry.value;
        if (file == null) continue;
        final url = await _uploadDoc(uid, 'photo_${entry.key}.jpg', file);
        if (url != null) photoUrls[entry.key] = url;
      }
      final registrationCardUrl = _registrationCardPhoto == null
          ? null
          : await _uploadDoc(
              uid,
              'registration_card.jpg',
              _registrationCardPhoto!,
            );
      final licenseUrl = _licensePhoto == null
          ? null
          : await _uploadDoc(uid, 'license.jpg', _licensePhoto!);

      final vehicle = DriverVehicle(
        vehicleType: widget.role.vehicleType,
        model: _modelController.text.trim(),
        year: int.parse(_yearController.text.trim()),
        plate: _plateController.text.trim(),
        seats: _seats!,
        color: _isCar ? _colorController.text.trim() : null,
        photoUrls: photoUrls,
        registrationCardUrl: registrationCardUrl,
        licenseUrl: licenseUrl,
      );

      await FirebaseFirestore.instance
          .collection('driver_profiles')
          .doc(uid)
          .set(vehicle.toMap());
      // Solde initialisé à 0 dans sa propre sous-collection, jamais dans
      // la fiche principale (voir firestore.rules : driver_profiles/wallet).
      await FirebaseFirestore.instance
          .collection('driver_profiles')
          .doc(uid)
          .collection('wallet')
          .doc('current')
          .set({'balance': 0});
      // Documents d'identité (carte grise, permis, photos) dans leur propre
      // sous-collection privée (voir firestore.rules : driver_profiles/documents).
      final documentsMap = vehicle.toDocumentsMap();
      if (documentsMap.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('driver_profiles')
            .doc(uid)
            .collection('documents')
            .doc('current')
            .set(documentsMap);
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'vehicleRegistered': true,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.wizardSubmitSuccess)),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.wizardSubmitError)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _step == 0
                        ? Navigator.of(context).maybePop()
                        : setState(() => _step -= 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: _StepIndicator(
                      step: _step,
                      labels: [
                        _isCar
                            ? AppStrings.wizardStepVehicleInfo
                            : AppStrings.wizardStepMotoInfo,
                        _isCar
                            ? AppStrings.wizardStepVehicleImages
                            : AppStrings.wizardStepMotoImages,
                        AppStrings.wizardStepDocuments,
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: switch (_step) {
                  0 => _InfoStep(
                    isCar: _isCar,
                    formKey: _formKey,
                    modelController: _modelController,
                    yearController: _yearController,
                    colorController: _colorController,
                    plateController: _plateController,
                    seats: _seats,
                    onSeatsChanged: (value) => setState(() => _seats = value),
                  ),
                  1 => _ImagesStep(
                    isCar: _isCar,
                    labels: _photoLabels,
                    photos: _photos,
                    onPick: (label) async {
                      final file = await _pickImage();
                      if (file != null) setState(() => _photos[label] = file);
                    },
                  ),
                  _ => _DocumentsStep(
                    isCar: _isCar,
                    registrationCard: _registrationCardPhoto,
                    license: _licensePhoto,
                    onPickRegistration: () async {
                      final file = await _pickImage();
                      if (file != null) {
                        setState(() => _registrationCardPhoto = file);
                      }
                    },
                    onPickLicense: () async {
                      final file = await _pickImage();
                      if (file != null) setState(() => _licensePhoto = file);
                    },
                  ),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _goNext,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _step < 2
                              ? AppStrings.wizardNext
                              : AppStrings.wizardSubmit,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.labels});

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final passed = (i ~/ 2) < step;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: passed ? AppColors.accent : AppColors.border,
            ),
          );
        }
        final index = i ~/ 2;
        final active = index == step;
        final done = index < step;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (active || done)
                    ? AppColors.accent
                    : AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: (active || done)
                      ? AppColors.background
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 80,
              child: Text(
                labels[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? AppColors.accentBright
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _InfoStep extends StatelessWidget {
  const _InfoStep({
    required this.isCar,
    required this.formKey,
    required this.modelController,
    required this.yearController,
    required this.colorController,
    required this.plateController,
    required this.seats,
    required this.onSeatsChanged,
  });

  final bool isCar;
  final GlobalKey<FormState> formKey;
  final TextEditingController modelController;
  final TextEditingController yearController;
  final TextEditingController colorController;
  final TextEditingController plateController;
  final int? seats;
  final ValueChanged<int?> onSeatsChanged;

  @override
  Widget build(BuildContext context) {
    final seatOptions = isCar ? const [2, 4, 5, 7] : const [1, 2];

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: isCar ? 'Informations ' : 'Informations '),
                TextSpan(
                  text: isCar ? 'du véhicule' : 'de la moto',
                  style: const TextStyle(color: AppColors.accentBright),
                ),
              ],
            ),
            style: Theme.of(context).textTheme.displayLarge
                ?.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 6),
          Text(
            isCar
                ? AppStrings.wizardVehicleInfoSubtitle
                : AppStrings.wizardMotoInfoSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _FieldLabel(
            isCar
                ? AppStrings.wizardFieldModelCar
                : AppStrings.wizardFieldModelMoto,
          ),
          TextFormField(
            controller: modelController,
            decoration: InputDecoration(
              hintText: isCar
                  ? AppStrings.wizardFieldModelCarHint
                  : AppStrings.wizardFieldModelMotoHint,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? AppStrings.wizardErrorRequired
                : null,
          ),
          const SizedBox(height: 18),
          _FieldLabel(AppStrings.wizardFieldYear),
          TextFormField(
            controller: yearController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: AppStrings.wizardFieldYearHint,
              suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
            ),
            validator: (v) {
              final year = int.tryParse(v?.trim() ?? '');
              final currentYear = DateTime.now().year;
              if (year == null || year < 1990 || year > currentYear + 1) {
                return AppStrings.wizardErrorYearInvalid;
              }
              return null;
            },
          ),
          if (isCar) ...[
            const SizedBox(height: 18),
            const _FieldLabel(AppStrings.wizardFieldColor),
            TextFormField(
              controller: colorController,
              decoration: const InputDecoration(
                hintText: AppStrings.wizardFieldColorHint,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? AppStrings.wizardErrorRequired
                  : null,
            ),
          ],
          const SizedBox(height: 18),
          _FieldLabel(
            isCar
                ? AppStrings.wizardFieldPlateCar
                : AppStrings.wizardFieldPlateCar,
          ),
          TextFormField(
            controller: plateController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: isCar
                  ? AppStrings.wizardFieldPlateCarHint
                  : AppStrings.wizardFieldPlateMotoHint,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? AppStrings.wizardErrorRequired
                : null,
          ),
          const SizedBox(height: 18),
          const _FieldLabel(AppStrings.wizardFieldSeats),
          DropdownButtonFormField<int>(
            initialValue: seats,
            hint: Text(
              isCar
                  ? AppStrings.wizardFieldSeatsHint
                  : AppStrings.wizardFieldSeatsMotoHint,
            ),
            items: seatOptions
                .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                .toList(growable: false),
            onChanged: onSeatsChanged,
            validator: (v) => v == null ? AppStrings.wizardErrorRequired : null,
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ImagesStep extends StatelessWidget {
  const _ImagesStep({
    required this.isCar,
    required this.labels,
    required this.photos,
    required this.onPick,
  });

  final bool isCar;
  final List<String> labels;
  final Map<String, File?> photos;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final overview = isCar ? null : AppStrings.wizardPhotoOverview;
    final gridLabels = labels
        .where((l) => l != overview)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Images '),
              TextSpan(
                text: isCar ? 'du véhicule' : 'de la moto',
                style: const TextStyle(color: AppColors.accentBright),
              ),
            ],
          ),
          style: Theme.of(context).textTheme.displayLarge
              ?.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 6),
        Text(
          isCar
              ? AppStrings.wizardImagesVehicleSubtitle
              : AppStrings.wizardImagesMotoSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.85,
          children: gridLabels
              .map(
                (label) => _PhotoSlot(
                  label: label,
                  file: photos[label],
                  onTap: () => onPick(label),
                ),
              )
              .toList(growable: false),
        ),
        if (overview != null) ...[
          const SizedBox(height: 14),
          _PhotoSlot(
            label: overview,
            file: photos[overview],
            onTap: () => onPick(overview),
            height: 160,
          ),
        ],
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.label,
    required this.file,
    required this.onTap,
    this.height,
  });

  final String label;
  final File? file;
  final VoidCallback onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Expanded(
            child: file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      file!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text(
              AppStrings.wizardAddPhoto,
              style: TextStyle(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsStep extends StatelessWidget {
  const _DocumentsStep({
    required this.isCar,
    required this.registrationCard,
    required this.license,
    required this.onPickRegistration,
    required this.onPickLicense,
  });

  final bool isCar;
  final File? registrationCard;
  final File? license;
  final VoidCallback onPickRegistration;
  final VoidCallback onPickLicense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.wizardDocumentsTitle,
          style: Theme.of(context).textTheme.displayLarge
              ?.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.wizardDocumentsSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        _DocumentSlot(
          label: isCar
              ? AppStrings.wizardDocRegistrationCar
              : AppStrings.wizardDocRegistrationMoto,
          file: registrationCard,
          onTap: onPickRegistration,
        ),
        const SizedBox(height: 18),
        _DocumentSlot(
          label: AppStrings.wizardDocLicense,
          file: license,
          onTap: onPickLicense,
        ),
      ],
    );
  }
}

class _DocumentSlot extends StatelessWidget {
  const _DocumentSlot({
    required this.label,
    required this.file,
    required this.onTap,
  });

  final String label;
  final File? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          if (file != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                file!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text(
              AppStrings.wizardAddPhoto,
              style: TextStyle(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ],
      ),
    );
  }
}
