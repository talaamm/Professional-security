import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import '../services/app_strings.dart';

/// Opens the Google Form linked to the employee's current app language
/// (assets/links.json: "en-form"/"ar-form"/"he-form"), for reporting
/// issues, feedback, suggestions, or contacting the developer directly -
/// separate from the in-app "report an issue" flow, which only reaches
/// the admins.
Future<void> openDeveloperContactForm(BuildContext context) async {
  try {
    final jsonString = await rootBundle.loadString('assets/links.json');
    final links = json.decode(jsonString) as Map<String, dynamic>;
    final url = links['${AppStrings.current.value.code}-form'] as String?;

    if (url == null || !await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      throw Exception('form link unavailable');
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.t('profile_contact_developer_error'))),
    );
  }
}
