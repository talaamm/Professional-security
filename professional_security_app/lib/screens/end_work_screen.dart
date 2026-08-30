import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../config/theme.dart';
import '../models/work_session.dart';
import '../services/location_service.dart';
import '../services/work_session_service.dart';
import '../widgets/error_banner.dart';

enum _EndStage { checking, error, manual }

/// Finish-work flow: get GPS -> ask the backend to end the active session.
/// The backend re-checks the current position against the workplace
/// recorded at start; if it doesn't match (or the start location was never
/// recognized), this falls back to asking the employee to confirm their
/// location manually, and the session ends as unverified.
///
/// Pops `true` if the session ended verified, `false` if it ended
/// manual/unverified, or `null` if the employee backed out without
/// finishing.
class EndWorkScreen extends StatefulWidget {
  final WorkSession session;

  const EndWorkScreen({super.key, required this.session});

  @override
  State<EndWorkScreen> createState() => _EndWorkScreenState();
}

class _EndWorkScreenState extends State<EndWorkScreen> {
  final _locationService = LocationService();
  final _sessionService = WorkSessionService();
  final _manualNameController = TextEditingController();

  _EndStage _stage = _EndStage.checking;
  Position? _position;
  String? _error;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _attemptEnd();
  }

  @override
  void dispose() {
    _manualNameController.dispose();
    super.dispose();
  }

  Future<void> _attemptEnd() async {
    setState(() {
      _stage = _EndStage.checking;
      _error = null;
    });

    try {
      final position = await _locationService.getCurrentPosition();
      _position = position;

      await _sessionService.endWorkSession(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on LocationServiceException catch (e) {
      _fail(e.message);
    } on WorkSessionException catch (e) {
      if (e.message == 'LOCATION_MISMATCH') {
        if (!mounted) return;
        setState(() => _stage = _EndStage.manual);
      } else {
        _fail(e.message);
      }
    } catch (_) {
      _fail('Something went wrong. Please try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _stage = _EndStage.error;
    });
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
      await _sessionService.endWorkSession(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        manualLocationName: name,
      );
      if (!mounted) return;
      Navigator.of(context).pop(false);
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
      appBar: AppBar(title: const Text('Finish Work')),
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
      case _EndStage.checking:
        return const _CheckingView();
      case _EndStage.error:
        return _ErrorView(message: _error ?? 'Something went wrong.', onRetry: _attemptEnd);
      case _EndStage.manual:
        return _ManualEntryView(
          workplaceLabel: widget.session.workplaceLabel,
          controller: _manualNameController,
          error: _error,
          isSubmitting: _isSubmitting,
          onSubmit: _submitManualLocation,
          onTryAgain: _attemptEnd,
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
            'Confirming your location',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Checking that you're still at your workplace.",
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

class _ManualEntryView extends StatelessWidget {
  final String workplaceLabel;
  final TextEditingController controller;
  final String? error;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final VoidCallback onTryAgain;

  const _ManualEntryView({
    required this.workplaceLabel,
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
        Text(
          "Couldn't confirm you're at $workplaceLabel",
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please confirm where you are finishing work.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        if (error != null) ...[
          ErrorBanner(message: error!),
          const SizedBox(height: 16),
        ],
        const Text('CURRENT LOCATION',
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
                  'This session will be marked as unverified and reviewed by an administrator.',
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
                  : const Text('CONFIRM & FINISH WORK'),
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
