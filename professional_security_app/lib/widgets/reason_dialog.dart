import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Confirmation dialog with a required reason text field. Returns the
/// trimmed reason if confirmed, or null if cancelled.
///
/// Wrapped in a StatefulBuilder so the confirm button's enabled state
/// actually reacts to typing - a plain `builder: (context) => AlertDialog(...)`
/// never rebuilds on its own, so a naive `onPressed: text.isEmpty ? null : ...`
/// stays frozen at whatever the field held when the dialog first opened.
Future<String?> showRequiredReasonDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final controller = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Reason (required)'),
              onChanged: (_) => setDialogState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed:
                controller.text.trim().isEmpty ? null : () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true) return null;
  final reason = controller.text.trim();
  return reason.isEmpty ? null : reason;
}
