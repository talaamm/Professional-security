import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/app_strings.dart';

/// Bottom sheet to pick a display language, shared by the employee and
/// admin Profile screens. AppStrings.setLanguage() persists the choice
/// and triggers the app-wide rebuild (see main.dart's ValueListenableBuilder
/// on AppStrings.current) - so callers don't need to track their own copy
/// of the current language, it's read directly from AppStrings.current.
Future<void> pickLanguage({required BuildContext context}) async {
  final current = AppStrings.current.value;

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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppStrings.t('language_picker_title'),
                style: const TextStyle(
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

  await AppStrings.setLanguage(selected);
}
