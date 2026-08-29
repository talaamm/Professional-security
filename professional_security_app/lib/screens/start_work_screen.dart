import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../config/theme.dart';
import '../models/workplace_match.dart';
import '../services/location_service.dart';
import '../services/work_session_service.dart';
import '../widgets/error_banner.dart';

enum _Stage { checking, error, matches, manual }

/// Start-work flow: get GPS -> find nearby workplaces -> let the employee
/// confirm/pick one, or fall back to a manual entry when nothing is nearby.
/// Pops `true` if a session was started, so the caller can refresh.
class StartWorkScreen extends StatefulWidget {
  const StartWorkScreen({super.key});

  @override
  State<StartWorkScreen> createState() => _StartWorkScreenState();
}

class _StartWorkScreenState extends State<StartWorkScreen> {
  final _locationService = LocationService();
  final _sessionService = WorkSessionService();
  final _manualNameController = TextEditingController();

  _Stage _stage = _Stage.checking;
  Position? _position;
  List<WorkplaceMatch> _matches = [];
  String? _selectedWorkplaceId;
  String? _error;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _detectWorkplace();
  }

  @override
  void dispose() {
    _manualNameController.dispose();
    super.dispose();
  }

  Future<void> _detectWorkplace() async {
    setState(() {
      _stage = _Stage.checking;
      _error = null;
    });

    try {
      final position = await _locationService.getCurrentPosition();
      final matches = await _sessionService.findNearbyWorkplaces(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _position = position;
        _matches = matches;
        _selectedWorkplaceId = matches.isNotEmpty ? matches.first.workplaceId : null;
        _stage = matches.isEmpty ? _Stage.manual : _Stage.matches;
      });
    } on LocationServiceException catch (e) {
      _fail(e.message);
    } on WorkSessionException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Something went wrong. Please try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _stage = _Stage.error;
    });
  }

  Future<void> _confirmWorkplace() async {
    final position = _position;
    final workplaceId = _selectedWorkplaceId;
    if (position == null || workplaceId == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _sessionService.startWorkSession(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        workplaceId: workplaceId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on WorkSessionException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitManualLocation() async {
    final position = _position;
    final name = _manualNameController.text.trim();
    if (position == null || name.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _sessionService.startWorkSession(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        manualLocationName: name,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on WorkSessionException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Start Work')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case _Stage.checking:
        return const _CheckingView();
      case _Stage.error:
        return _ErrorView(message: _error ?? 'Something went wrong.', onRetry: _detectWorkplace);
      case _Stage.matches:
        return _MatchesView(
          matches: _matches,
          selectedWorkplaceId: _selectedWorkplaceId,
          error: _error,
          isSubmitting: _isSubmitting,
          onSelect: (id) => setState(() => _selectedWorkplaceId = id),
          onConfirm: _confirmWorkplace,
          onEnterManually: () => setState(() {
            _error = null;
            _stage = _Stage.manual;
          }),
        );
      case _Stage.manual:
        return _ManualEntryView(
          controller: _manualNameController,
          error: _error,
          isSubmitting: _isSubmitting,
          onSubmit: _submitManualLocation,
          onTryAgain: _detectWorkplace,
        );
    }
  }
}

class _CheckingView extends StatelessWidget {
  const _CheckingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 24),
          Text(
            'Checking your workplace',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Verifying that you're at an approved workplace.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
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
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

class _MatchesView extends StatelessWidget {
  final List<WorkplaceMatch> matches;
  final String? selectedWorkplaceId;
  final String? error;
  final bool isSubmitting;
  final ValueChanged<String> onSelect;
  final VoidCallback onConfirm;
  final VoidCallback onEnterManually;

  const _MatchesView({
    required this.matches,
    required this.selectedWorkplaceId,
    required this.error,
    required this.isSubmitting,
    required this.onSelect,
    required this.onConfirm,
    required this.onEnterManually,
  });

  @override
  Widget build(BuildContext context) {
    final title = matches.length == 1 ? 'Workplace detected' : 'Multiple workplaces nearby';
    final subtitle = matches.length == 1
        ? "You're within the approved workplace area."
        : 'Select the workplace you are currently at.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        if (error != null) ...[
          ErrorBanner(message: error!),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: ListView.separated(
            itemCount: matches.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final match = matches[index];
              final selected = match.workplaceId == selectedWorkplaceId;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelect(match.workplaceId),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: selected ? AppColors.primary : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              match.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${match.distanceMeters.round()}m away',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: (isSubmitting || selectedWorkplaceId == null) ? null : onConfirm,
          child: isSubmitting
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Text('CONFIRM & START WORK'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: isSubmitting ? null : onEnterManually,
          child: const Text("None of these? Enter location manually"),
        ),
      ],
    );
  }
}

class _ManualEntryView extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final VoidCallback onTryAgain;

  const _ManualEntryView({
    required this.controller,
    required this.error,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.location_searching, color: AppColors.secondary, size: 40),
        const SizedBox(height: 12),
        const Text(
          'Workplace not detected',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "We couldn't automatically identify an approved workplace near you.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        if (error != null) ...[
          ErrorBanner(message: error!),
          const SizedBox(height: 16),
        ],
        const Text('WORKPLACE / ASSIGNMENT LOCATION',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'e.g. Wedding Hall - Beit Hanina'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.secondary, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your location could not be verified automatically. This session will be marked as manual and reviewed by an administrator.',
                  style: TextStyle(color: AppColors.secondary),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            return ElevatedButton(
              onPressed: (isSubmitting || value.text.trim().isEmpty) ? null : onSubmit,
              child: isSubmitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('SUBMIT'),
            );
          },
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: isSubmitting ? null : onTryAgain,
          child: const Text('Try Again'),
        ),
      ],
    );
  }
}
