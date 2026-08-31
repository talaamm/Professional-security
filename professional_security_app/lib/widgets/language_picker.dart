import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/language_service.dart';

/// Bottom sheet to pick a display language, shared by the employee and
/// admin Profile screens. Only remembers the choice on this device
/// (LanguageService) - nothing in the app reads it yet.
Future<void> pickLanguage({
  required BuildContext context,
  required AppLanguage current,
  required ValueChanged<AppLanguage> onChanged,
}) async {
  final languageService = LanguageService();

  final selected = await showModalBottomSheet<AppLanguage>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (context) => SafeArea(
      child: RadioGroup<AppLanguage>(
        groupValue: current,
        onChanged: (value) => Navigator.of(context).pop(value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Choose Language',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            for (final lang in AppLanguage.values)
              RadioListTile<AppLanguage>(
                value: lang,
                activeColor: AppColors.primary,
                title: Text(lang.label, style: const TextStyle(color: AppColors.textPrimary)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );

  if (selected == null || selected == current) return;

  await languageService.setLanguage(selected);
  onChanged(selected);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Language set to ${selected.label}. Full translation coming soon.')),
  );
}
