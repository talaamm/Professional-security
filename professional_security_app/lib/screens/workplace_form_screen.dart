import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../models/workplace.dart';
import '../services/admin_service.dart';
import '../services/location_service.dart';
import '../widgets/error_banner.dart';

const int _defaultExpectedRadius = 100;
// Above this, GPS is degraded enough (e.g. indoors, urban canyon) that we
// warn the admin rather than silently baking a huge buffer into the radius.
const double _poorAccuracyThresholdMeters = 30;
const int _maxRadiusMeters = 10000; // matches workplaces_radius_reasonable

enum _CaptureState { checking, ready, error }

/// Add a new workplace (standing at its physical location) or edit an
/// existing one. Adding always starts by capturing GPS - see
/// requirements-and-architecture_V1.md section 12.2 ("GPS location
/// captured -> Accuracy checked -> Admin enters name -> System
/// calculates/sets default radius -> Admin confirms"). Editing shows the
/// stored location and only re-captures GPS if the admin taps Recalibrate
/// (they may be editing remotely, not standing at the site).
///
/// The saved radius is always "expected radius + GPS accuracy" whenever a
/// fresh capture is available this session (a wider radius than what the
/// admin typed compensates for how far off the captured coordinates
/// themselves might be) - with no fresh capture (editing without
/// recalibrating), the expected-radius field is simply the stored radius.
class WorkplaceFormScreen extends StatefulWidget {
  final Profile adminProfile;
  final Workplace? existing;

  const WorkplaceFormScreen({super.key, required this.adminProfile, this.existing});

  @override
  State<WorkplaceFormScreen> createState() => _WorkplaceFormScreenState();
}

class _WorkplaceFormScreenState extends State<WorkplaceFormScreen> {
  final _locationService = LocationService();
  final _adminService = AdminService();
  final _nameController = TextEditingController();
  final _radiusController = TextEditingController();

  late final bool _isEditing = widget.existing != null;
  late String _type = widget.existing?.type ?? 'permanent';

  _CaptureState _captureState = _CaptureState.checking;
  String? _captureError;
  Position? _freshPosition;
  bool _isRecalibrating = false;

  bool _isSubmitting = false;
  String? _error;
  bool _isUpdatingStatus = false;
  late bool _isActive = widget.existing?.isActive ?? true;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.existing?.name ?? '';
    _radiusController.text = (widget.existing?.radiusMeters ?? _defaultExpectedRadius).toString();

    if (_isEditing) {
      _captureState = _CaptureState.ready;
    } else {
      _captureLocation();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    // Only the very first capture (adding, before any location exists at
    // all) blocks the whole screen - a later recapture/recalibrate tap
    // shows an inline spinner on the button instead, so the rest of the
    // form (name, radius, type already typed in) stays visible.
    final isFirstCapture = !_isEditing && _freshPosition == null;

    setState(() {
      if (isFirstCapture) _captureState = _CaptureState.checking;
      _isRecalibrating = true;
      _captureError = null;
    });

    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _freshPosition = position;
        _captureState = _CaptureState.ready;
      });
    } on LocationServiceException catch (e) {
      _failCapture(e.message);
    } catch (_) {
      _failCapture('Could not determine your location. Please try again.');
    } finally {
      if (mounted) setState(() => _isRecalibrating = false);
    }
  }

  void _failCapture(String message) {
    if (!mounted) return;
    setState(() {
      _captureError = message;
      // Editing already has a stored location to fall back on, so a
      // failed recalibration attempt shouldn't block the whole form.
      _captureState = _isEditing ? _CaptureState.ready : _CaptureState.error;
    });
  }

  double? get _latitude => _freshPosition?.latitude ?? widget.existing?.latitude;
  double? get _longitude => _freshPosition?.longitude ?? widget.existing?.longitude;

  int? get _expectedRadius => int.tryParse(_radiusController.text.trim());

  int? get _effectiveRadius {
    final expected = _expectedRadius;
    if (expected == null || expected <= 0) return null;
    final accuracy = _freshPosition?.accuracy;
    final raw = accuracy == null ? expected : expected + accuracy;
    return raw.round();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final latitude = _latitude;
    final longitude = _longitude;
    final radius = _effectiveRadius;

    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name for this workplace.');
      return;
    }
    if (latitude == null || longitude == null) {
      setState(() => _error = 'A location is required. Please capture the GPS location.');
      return;
    }
    if (radius == null || radius <= 0) {
      setState(() => _error = 'Please enter a valid radius.');
      return;
    }
    if (radius > _maxRadiusMeters) {
      setState(() => _error = 'Radius is too large (max $_maxRadiusMeters m).');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await _adminService.updateWorkplace(
          id: widget.existing!.id,
          name: name,
          radiusMeters: radius,
          type: _type,
          latitude: _freshPosition?.latitude,
          longitude: _freshPosition?.longitude,
        );
      } else {
        await _adminService.createWorkplace(
          name: name,
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radius,
          type: _type,
          createdBy: widget.adminProfile.employeeId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AdminServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmToggleStatus() async {
    final activating = !_isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          activating ? 'Activate this workplace?' : 'Deactivate this workplace?',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          activating
              ? 'Employees will be able to start/end sessions here again.'
              : 'Employees will no longer be matched to this workplace. Past sessions here are kept.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: activating
                ? null
                : ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(activating ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isUpdatingStatus = true;
      _error = null;
    });

    try {
      await _adminService.setWorkplaceStatus(id: widget.existing!.id, active: activating);
      if (!mounted) return;
      setState(() => _isActive = activating);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(activating ? 'Workplace activated.' : 'Workplace deactivated.')),
      );
    } on AdminServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEditing ? 'Edit Workplace' : 'Add Workplace')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_captureState == _CaptureState.checking) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 24),
            Text(
              'Capturing your location',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Stand at the workplace before continuing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_captureState == _CaptureState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.location_off_outlined, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Location error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _captureError ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _captureLocation, child: const Text('Try Again')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          _buildLocationCard(),
          const SizedBox(height: 20),
          const Text('NAME', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'e.g. Event Hall A'),
          ),
          const SizedBox(height: 16),
          const Text('TYPE', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'permanent', label: Text('Permanent')),
              ButtonSegment(value: 'temporary', label: Text('Temporary')),
            ],
            selected: {_type},
            onSelectionChanged: (selected) => setState(() => _type = selected.first),
          ),
          const SizedBox(height: 16),
          Text(
            _freshPosition != null ? 'EXPECTED RADIUS' : 'RADIUS (METERS)',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _radiusController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'e.g. 100'),
            onChanged: (_) => setState(() {}),
          ),
          if (_freshPosition != null) ...[
            const SizedBox(height: 12),
            _buildCalibrationPreview(),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : Text(_isEditing ? 'SAVE CHANGES' : 'CREATE WORKPLACE'),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isUpdatingStatus ? null : _confirmToggleStatus,
              style: _isActive
                  ? OutlinedButton.styleFrom(foregroundColor: AppColors.error)
                  : null,
              child: _isUpdatingStatus
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : Text(_isActive ? 'DEACTIVATE WORKPLACE' : 'ACTIVATE WORKPLACE'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final latitude = _latitude;
    final longitude = _longitude;
    final accuracy = _freshPosition?.accuracy;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                accuracy != null ? 'Captured location' : 'Stored location',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            latitude != null && longitude != null
                ? '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'
                : 'Not captured yet.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (accuracy != null) ...[
            const SizedBox(height: 2),
            Text(
              'GPS accuracy: ±${accuracy.round()}m',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          if (accuracy != null && accuracy > _poorAccuracyThresholdMeters) ...[
            const SizedBox(height: 8),
            const Text(
              '⚠ GPS accuracy is low. Move outdoors/away from tall buildings and recapture for a tighter reading.',
              style: TextStyle(color: AppColors.secondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isRecalibrating ? null : _captureLocation,
            icon: _isRecalibrating
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.gps_fixed, size: 18),
            label: Text(_isEditing ? 'Recalibrate at Current Location' : 'Recapture Location'),
          ),
          if (_captureError != null && _isEditing) ...[
            const SizedBox(height: 8),
            Text(_captureError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildCalibrationPreview() {
    final effective = _effectiveRadius;
    final accuracy = _freshPosition!.accuracy;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        effective == null
            ? 'Enter a radius to see the calibrated value.'
            : 'Effective radius: ${effective}m  (${_radiusController.text.trim()}m expected '
                '+ ±${accuracy.round()}m GPS accuracy)',
        style: const TextStyle(color: AppColors.textPrimary),
      ),
    );
  }
}
