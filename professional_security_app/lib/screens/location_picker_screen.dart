import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../models/geo_place.dart';
import '../services/app_strings.dart';
import '../services/geocoding_service.dart';
import '../widgets/error_banner.dart';

/// Result handed back to WorkplaceFormScreen when the admin confirms a
/// location. [name] is only a display label (from the search result the
/// admin picked, or null if they fine-tuned the pin by tapping the map) -
/// it is never sent to the backend.
class LocationPickerResult {
  final String? name;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  const LocationPickerResult({
    this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });
}

// Schema only requires radius_meters > 0 and <= 10000
// (workplaces_radius_reasonable, db-schema-V2.sql). 25m is a practical
// slider floor, not a schema minimum. 100m matches the column's default.
const List<int> _radiusPresets = [
  25, 50, 75, 100, 150, 200, 250, 300, 500, 750, 1000, 1500, 2000, 3000, 5000, 7500, 10000,
];
const int _defaultRadiusMeters = 100;

// Jerusalem - a sane starting view when the admin hasn't searched yet
// (e.g. "Hadassah Hospital"). Purely a default camera position, never
// sent anywhere unless the admin actually selects a point.
const LatLng _fallbackCenter = LatLng(31.7683, 35.2137);

/// "Choose Location" experience: search a place by name/address, tap the
/// map to fine-tune the exact spot, and pick the allowed GPS radius with a
/// slider - independent of the admin's own device location.
class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final int? initialRadiusMeters;
  final String? initialName;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialRadiusMeters,
    this.initialName,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _geocodingService = GeocodingService();
  final _mapController = MapController();
  final _searchController = TextEditingController();

  LatLng? _selectedPoint;
  String? _selectedName;
  late int _radiusIndex = _closestPresetIndex(widget.initialRadiusMeters);

  List<GeoPlace> _results = [];
  bool _isSearching = false;
  String? _searchError;
  bool _tileLoadFailed = false;

  static int _closestPresetIndex(int? radius) {
    final target = radius ?? _defaultRadiusMeters;
    var bestIndex = 0;
    var bestDiff = (target - _radiusPresets[0]).abs();
    for (var i = 1; i < _radiusPresets.length; i++) {
      final diff = (target - _radiusPresets[i]).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPoint = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _selectedName = widget.initialName;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _radiusMeters => _radiusPresets[_radiusIndex];

  LatLng get _mapCenter => _selectedPoint ?? _fallbackCenter;

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _results = [];
    });

    try {
      final results = await _geocodingService.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) {
          _searchError = AppStrings.t('location_picker_no_results');
        }
      });
    } on GeocodingException catch (e) {
      if (!mounted) return;
      setState(() => _searchError = e.message);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectResult(GeoPlace place) {
    final point = LatLng(place.latitude, place.longitude);
    setState(() {
      _selectedPoint = point;
      _selectedName = place.displayName;
      _results = [];
      _searchError = null;
    });
    _searchController.clear();
    FocusScope.of(context).unfocus();
    _mapController.move(point, 16);
  }

  void _selectMapPoint(LatLng point) {
    setState(() {
      _selectedPoint = point;
      _selectedName = null;
      _results = [];
      _searchError = null;
    });
    FocusScope.of(context).unfocus();
  }

  void _confirm() {
    final point = _selectedPoint;
    if (point == null) return;
    Navigator.of(context).pop(LocationPickerResult(
      name: _selectedName,
      latitude: point.latitude,
      longitude: point.longitude,
      radiusMeters: _radiusMeters,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(AppStrings.t('location_picker_title'))),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: AppStrings.t('location_picker_search_hint'),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward, color: AppColors.primary),
                          onPressed: _search,
                        ),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            if (_searchError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ErrorBanner(message: _searchError!),
              ),
            if (_results.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.background),
                  itemBuilder: (context, index) {
                    final place = _results[index];
                    return ListTile(
                      leading: const Icon(Icons.place_outlined, color: AppColors.primary),
                      title: Text(
                        place.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      onTap: () => _selectResult(place),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            if (_tileLoadFailed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: ErrorBanner(message: AppStrings.t('location_picker_map_load_error')),
              ),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mapCenter,
                      initialZoom: _selectedPoint != null ? 16 : 8,
                      onTap: (_, point) => _selectMapPoint(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.halabi.professionalsecurity',
                        errorTileCallback: (tile, error, stackTrace) {
                          if (!_tileLoadFailed && mounted) {
                            setState(() => _tileLoadFailed = true);
                          }
                        },
                      ),
                      if (_selectedPoint != null) ...[
                        CircleLayer(circles: [
                          CircleMarker(
                            point: _selectedPoint!,
                            radius: _radiusMeters.toDouble(),
                            useRadiusInMeter: true,
                            color: AppColors.primary.withValues(alpha: 0.18),
                            borderColor: AppColors.primary,
                            borderStrokeWidth: 2,
                          ),
                        ]),
                        MarkerLayer(markers: [
                          Marker(
                            point: _selectedPoint!,
                            width: 36,
                            height: 36,
                            child: const Icon(Icons.location_pin, color: AppColors.primary, size: 36),
                          ),
                        ]),
                      ],
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                            onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_selectedPoint == null)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          AppStrings.t('location_picker_select_prompt'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    final point = _selectedPoint;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                AppStrings.t('location_picker_radius_section'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const Spacer(),
              Text(
                AppStrings.t('location_picker_radius_label', {'radius': '$_radiusMeters'}),
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Slider(
            value: _radiusIndex.toDouble(),
            min: 0,
            max: (_radiusPresets.length - 1).toDouble(),
            divisions: _radiusPresets.length - 1,
            label: '$_radiusMeters m',
            onChanged: (value) => setState(() => _radiusIndex = value.round()),
          ),
          if (point != null) ...[
            const SizedBox(height: 4),
            Text(
              _selectedName ?? AppStrings.t('location_picker_unnamed_location'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 12),
          ElevatedButton(
            onPressed: point == null ? null : _confirm,
            child: Text(AppStrings.t('location_picker_confirm_button')),
          ),
        ],
      ),
    );
  }
}
