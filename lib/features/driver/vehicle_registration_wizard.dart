import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/driver_vehicle.dart';
import '../../models/vehicle_type.dart';
import '../../repositories/driver_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/wallet_repository.dart';
import 'wizard/documents_step.dart';
import 'wizard/images_step.dart';
import 'wizard/info_step.dart';
import 'wizard/step_indicator.dart';

/// Assistant d'inscription du véhicule en 3 étapes : informations,
/// photos, documents — requis avant qu'un chauffeur reçoive des courses.
class VehicleRegistrationWizard extends StatefulWidget {
  const VehicleRegistrationWizard({super.key, required this.vehicleType});

  final VehicleType vehicleType;

  @override
  State<VehicleRegistrationWizard> createState() =>
      _VehicleRegistrationWizardState();
}

class _VehicleRegistrationWizardState extends State<VehicleRegistrationWizard> {
  static final _picker = ImagePicker();

  late final bool _isCar = widget.vehicleType == VehicleType.car;
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
        vehicleType: widget.vehicleType,
        model: _modelController.text.trim(),
        year: int.parse(_yearController.text.trim()),
        plate: _plateController.text.trim(),
        seats: _seats!,
        color: _isCar ? _colorController.text.trim() : null,
        photoUrls: photoUrls,
        registrationCardUrl: registrationCardUrl,
        licenseUrl: licenseUrl,
      );

      await DriverRepository().profileRef(uid).set(vehicle.toMap());
      // Solde initialisé à 0 dans sa propre sous-collection, jamais dans
      // la fiche principale (voir firestore.rules : driver_profiles/wallet).
      await WalletRepository().walletRef(uid)
          .set({'balance': 0});
      // Documents d'identité (carte grise, permis, photos) dans leur propre
      // sous-collection privée (voir firestore.rules : driver_profiles/documents).
      final documentsMap = vehicle.toDocumentsMap();
      if (documentsMap.isNotEmpty) {
        await DriverRepository().documentsRef(uid)
            .set(documentsMap);
      }
      await UserRepository().updateUser(uid, {
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
                    child: StepIndicator(
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: switch (_step) {
                    0 => InfoStep(
                      isCar: _isCar,
                      formKey: _formKey,
                      modelController: _modelController,
                      yearController: _yearController,
                      colorController: _colorController,
                      plateController: _plateController,
                      seats: _seats,
                      onSeatsChanged: (value) => setState(() => _seats = value),
                    ),
                    1 => ImagesStep(
                      isCar: _isCar,
                      labels: _photoLabels,
                      photos: _photos,
                      onPick: (label) async {
                        final file = await _pickImage();
                        if (file != null) setState(() => _photos[label] = file);
                      },
                    ),
                    _ => DocumentsStep(
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
