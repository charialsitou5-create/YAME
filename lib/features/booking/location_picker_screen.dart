import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../services/place_search_service.dart';

class PickedLocation {
  const PickedLocation({required this.point, this.address});

  final LatLng point;
  final String? address;
}

/// Carte plein écran pour choisir UN seul point (départ ou destination) :
/// on cherche d'abord un lieu par écrit (comme InDrive), puis on affine en
/// déplaçant la carte sous l'épingle centrale, et on confirme.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.title,
    required this.initialCenter,
    this.initialPoint,
    this.pinColor = Colors.green,
  });

  final String title;
  final LatLng initialCenter;
  final LatLng? initialPoint;
  final Color pinColor;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _map = MapController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  late LatLng _center = widget.initialPoint ?? widget.initialCenter;
  List<PlaceResult> _results = const [];
  bool _searching = false;
  String? _address;
  int _geoSeq = 0;

  @override
  void initState() {
    super.initState();
    _reverse(_center);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _searching = true);
      final res = await PlaceSearchService.search(value, near: _center);
      if (!mounted) return;
      setState(() {
        _results = res;
        _searching = false;
      });
    });
  }

  void _selectResult(PlaceResult r) {
    FocusScope.of(context).unfocus();
    setState(() {
      _results = const [];
      _center = r.point;
      _address = r.label;
    });
    _map.move(r.point, 17);
  }

  Future<void> _reverse(LatLng p) async {
    final seq = ++_geoSeq;
    String? address;
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(
        p.latitude,
        p.longitude,
      );
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        final parts = [pm.street, pm.subLocality, pm.locality]
            .whereType<String>()
            .where((part) => part.isNotEmpty);
        address = parts.isEmpty ? null : parts.join(', ');
      }
    } catch (_) {}
    if (!mounted || seq != _geoSeq) return;
    setState(() => _address = address);
  }

  Future<void> _goToMe() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('denied');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final p = LatLng(pos.latitude, pos.longitude);
      _map.move(p, 17);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.bookingLocationDenied)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initialPoint != null ? 17 : 15,
              onPositionChanged: (camera, hasGesture) {
                _center = camera.center;
                if (hasGesture) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 400),
                    () => _reverse(_center),
                  );
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yame.yame',
              ),
            ],
          ),
          // Épingle fixe au centre : le point choisi est celui sous l'épingle.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Icon(Icons.location_on, color: widget.pinColor, size: 48),
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.surface,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onQueryChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: AppStrings.pickerSearchHint,
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(
                          _results[i].label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectResult(_results[i]),
                      ),
                    ),
                  )
                else if (_searchController.text.trim().length >= 3 &&
                    !_searching)
                  const SizedBox.shrink(),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 130,
            child: FloatingActionButton.small(
              heroTag: 'picker-locate',
              onPressed: _goToMe,
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.accent,
              child: const Icon(Icons.my_location),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.title,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    _address ?? '…',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(
                      PickedLocation(point: _center, address: _address),
                    ),
                    child: const Text(AppStrings.pickerConfirm),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
