import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/unverified_session.dart';
import '../services/admin_service.dart';
import '../widgets/error_banner.dart';
import '../widgets/reason_dialog.dart';

enum SessionReviewOutcome { verified, deleted }

/// Admin review of one unverified (completed) session: shows the employee,
/// why it needs review, and the location the employee claimed for
/// whichever side didn't auto-verify - editable before confirming. Also
/// lets the admin delete the session outright instead of verifying it.
///
/// Pops a SessionReviewOutcome if something happened, or null if the admin
/// backed out without doing anything.
class SessionReviewScreen extends StatefulWidget {
  final UnverifiedSession session;

  const SessionReviewScreen({super.key, required this.session});

  @override
  State<SessionReviewScreen> createState() => _SessionReviewScreenState();
}

class _SessionReviewScreenState extends State<SessionReviewScreen> {
  final _adminService = AdminService();
  late final _startController =
      TextEditingController(text: widget.session.claimedStartLocation);
  late final _endController =
      TextEditingController(text: widget.session.claimedEndLocation);
  final _noteController = TextEditingController();

  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (widget.session.startNeedsReview && _startController.text.trim().isEmpty) {
      return false;
    }
    if (widget.session.endNeedsReview && _endController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _adminService.verifySession(
        sessionId: widget.session.sessionId,
        startLocationName:
            widget.session.startNeedsReview ? _startController.text.trim() : null,
        endLocationName:
            widget.session.endNeedsReview ? _endController.text.trim() : null,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(SessionReviewOutcome.verified);
    } on AdminServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmDelete() async {
    final reason = await showRequiredReasonDialog(
      context: context,
      title: 'Delete this session?',
      message: 'This permanently removes the session. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (reason == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _adminService.deleteSession(sessionId: widget.session.sessionId, reason: reason);
      if (!mounted) return;
      Navigator.of(context).pop(SessionReviewOutcome.deleted);
    } on AdminServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day}/${dt.year}  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Review Session')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            session.employeeName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Employee ID: ${session.employeeId}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'Workplace', value: session.workplaceLabel),
                _DetailRow(label: 'Started', value: _formatDateTime(session.startedAt)),
                _DetailRow(label: 'Ended', value: _formatDateTime(session.endedAt)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.secondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(session.reason, style: const TextStyle(color: AppColors.secondary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          if (session.startNeedsReview) ...[
            const Text('EMPLOYEE\'S CLAIMED START LOCATION',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _startController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'e.g. Wedding Hall - Beit Hanina'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
          ],
          if (session.endNeedsReview) ...[
            const Text('EMPLOYEE\'S CLAIMED END LOCATION',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _endController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'e.g. Wedding Hall - Beit Hanina'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
          ],
          const Text('NOTE (OPTIONAL)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            style: const TextStyle(color: AppColors.textPrimary),
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Reason for this correction'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_isSubmitting || !_canSubmit) ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text('VERIFY SESSION'),
          ),
          const SizedBox(height: 24),
          const Divider(color: AppColors.surface),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isSubmitting ? null : _confirmDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            child: const Text('DELETE SESSION'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
