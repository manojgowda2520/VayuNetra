import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_strings.dart';
import '../services/storage_service.dart';

class LanguageProvider extends ChangeNotifier {
  String _languageCode = 'en';

  String get languageCode => _languageCode;
  String get languageLabel => _languageCode == 'kn'
      ? 'Kannada'
      : _languageCode == 'hi'
          ? 'Hindi'
          : 'English';

  LanguageProvider() {
    loadLanguage();
  }

  Future<void> loadLanguage() async {
    _languageCode = await StorageService.getLanguage();
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _languageCode = lang;
    await StorageService.setLanguage(lang);
    notifyListeners();
  }

  String t(String key) {
    return appStrings[_languageCode]?[key]
        ?? appStrings['en']?[key]
        ?? key;
  }
}

extension LanguageContext on BuildContext {
  String t(String key) => read<LanguageProvider>().t(key);
}
