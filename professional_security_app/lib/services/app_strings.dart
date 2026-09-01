import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'language_service.dart';

export 'language_service.dart' show AppLanguage, AppLanguageX;

/// Lightweight JSON-based translations for English/Arabic/Hebrew
/// (assets/lang/en.json, ar.json, he.json - one flat key -> text map per
/// language). Deliberately not using Flutter's ARB/gen-l10n tooling - a
/// plain JSON lookup is simpler for a small app and needs no code
/// generation step.
///
/// [current] is a ValueNotifier so main.dart can rebuild the whole app
/// (Directionality + every translated string) the moment the language
/// changes from the Profile tab - see pickLanguage() in
/// widgets/language_picker.dart.
class AppStrings {
  AppStrings._();

  static final ValueNotifier<AppLanguage> current = ValueNotifier(AppLanguage.english);
  static Map<String, dynamic> _map = {};

  /// Loads the saved language preference before the first frame. Call
  /// once, from main(), before runApp().
  static Future<void> init() async {
    final saved = await LanguageService().getLanguage();
    await _load(saved);
    current.value = saved;
  }

  static Future<void> setLanguage(AppLanguage language) async {
    if (language == current.value) return;
    await LanguageService().setLanguage(language);
    await _load(language);
    current.value = language;
  }

  static Future<void> _load(AppLanguage language) async {
    final jsonString = await rootBundle.loadString('assets/lang/${language.code}.json');
    _map = json.decode(jsonString) as Map<String, dynamic>;
  }

  /// Looks up [key] and substitutes any `{name}`-style placeholders from
  /// [args]. Falls back to the key itself when it's missing from the
  /// loaded file, so an untranslated string is visibly wrong instead of
  /// crashing the app.
  static String t(String key, [Map<String, String>? args]) {
    final raw = _map[key];
    var value = raw is String ? raw : key;
    if (args != null) {
      for (final entry in args.entries) {
        value = value.replaceAll('{${entry.key}}', entry.value);
      }
    }
    return value;
  }

  static List<String> list(String key) {
    final raw = _map[key];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  /// UnverifiedSession.reason (models/unverified_session.dart) builds its
  /// explanation from these same two booleans - this mirrors that logic
  /// for display instead of string-matching its fixed English sentences.
  static String unverifiedReason(bool startNeedsReview, bool endNeedsReview) {
    if (startNeedsReview && endNeedsReview) return t('unverified_reason_both');
    if (startNeedsReview) return t('unverified_reason_start');
    return t('unverified_reason_end');
  }
}
