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

  String get label {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.arabic:
        return 'Arabic';
      case AppLanguage.hebrew:
        return 'Hebrew';
    }
  }
}

/// Stores the employee's chosen display language on this device. This is
/// just a preference for now - the app doesn't translate its screens yet,
/// per your instructions ("we will modify the languages in the app
/// later"). Local device storage is enough for a preference nothing reads
/// yet; there's nothing here to sync across devices.
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
