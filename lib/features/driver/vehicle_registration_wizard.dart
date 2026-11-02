import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/validators.dart';
import '../../models/driver_vehicle.dart';
import '../../models/vehicle_type.dart';
import '../../repositories/driver_repository.dart';
import '../../repositories/user_repository.dart';
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
  bool _specialPlate = false;

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

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _goNext() {
    if (_step == 0 && !_formKey.currentState!.validate()) return;
    // Photos du véhicule : TOUTES obligatoires (l'admin doit pouvoir les vérifier).
    if (_step == 1 && _photoLabels.any((l) => _photos[l] == null)) {
      _showError(AppStrings.wizardErrorPhotoMissing);
      return;
    }
    // Documents : carte grise et permis obligatoires.
    if (_step == 2 && (_registrationCardPhoto == null || _licensePhoto == null)) {
      _showError(AppStrings.wizardErrorDocsMissing);
      return;
    }
    if (_step < 2) {
      setState(() => _step += 1);
    } else {
      _submit();
    }
  }

  /// `null` en cas d'échec d'envoi : l'inscription est alors INTERROMPUE
  /// (voir [_submit]) — jamais d'inscription sans photos exploitables.
  Future<String?> _uploadDoc(String uid, String path, File file) async {
    try {
      // Bucket privé : on garde le chemin (pas d'URL), l'admin génère un lien signé à la consultation.
      final objectPath = '$uid/$path';
      await Supabase.instance.client.storage
          .from('driver-documents')
          .upload(objectPath, file, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
      return objectPath;
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);
    try {
      if (_photoLabels.any((l) => _photos[l] == null) ||
          _registrationCardPhoto == null ||
          _licensePhoto == null) {
        _showError(AppStrings.wizardErrorPhotoMissing);
        return;
      }
      final photoUrls = <String, String>{};
      for (var i = 0; i < _photoLabels.length; i++) {
        final label = _photoLabels[i];
        // Chemin ASCII (les libellés ont des accents/apostrophes que le stockage peut refuser).
        final url = await _uploadDoc(uid, 'photo_$i.jpg', _photos[label]!);
        if (url == null) {
          _showError(AppStrings.wizardErrorUpload);
          return;
        }
        photoUrls[label] = url;
      }
      final registrationCardUrl = await _uploadDoc(
        uid,
        'registration_card.jpg',
        _registrationCardPhoto!,
      );
      final licenseUrl = await _uploadDoc(uid, 'license.jpg', _licensePhoto!);
      if (registrationCardUrl == null || licenseUrl == null) {
        _showError(AppStrings.wizardErrorUpload);
        return;
      }

      final vehicle = DriverVehicle(
        vehicleType: widget.vehicleType,
        model: _modelController.text.trim(),
        year: int.parse(_yearController.text.trim()),
        plate: normalizePlate(_plateController.text),
        seats: _seats!,
        color: _isCar ? _colorController.text.trim() : null,
        photoUrls: photoUrls,
        registrationCardUrl: registrationCardUrl,
        licenseUrl: licenseUrl,
      );

      // Fiche véhicule, portefeuille à 0 et documents d'identité (table privée) en un appel.
      await DriverRepository().registerVehicle(uid, vehicle.toMap(), vehicle.toDocumentsMap());
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
                      specialPlate: _specialPlate,
                      onSpecialPlateChanged: (v) {
                        setState(() => _specialPlate = v);
                        _formKey.currentState?.validate();
                      },
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
