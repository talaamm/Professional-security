import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, arabic, hebrew }

extension AppLanguageX on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.arabic:
        return 'ar';
      case AppLanguage.hebrew:
        return 'he';
    }
  }

  /// Shown in the language picker in each language's own script, not
  /// translated into the currently-active language - the standard
  /// convention (a Hebrew speaker still looks for "English", not its
  /// Hebrew translation).
  String get label {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.arabic:
        return 'العربية';
      case AppLanguage.hebrew:
        return 'עברית';
    }
  }

  bool get isRtl => this == AppLanguage.arabic || this == AppLanguage.hebrew;
}

/// Stores the employee's chosen display language on this device. Read by
/// AppStrings at startup and whenever the Profile tab's language picker
/// changes it.
class LanguageService {
  static const _prefsKey = 'app_language';

  Future<AppLanguage> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.english,
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, language.code);
  }
}
