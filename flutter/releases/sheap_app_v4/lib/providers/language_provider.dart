import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

class LanguageProvider with ChangeNotifier {
  Locale _locale = const Locale('en'); // Default to English

  Locale get locale => _locale;

  LanguageProvider() {
    // When the provider is created, load the saved language
    loadLocale();
  }

  void setLocale(Locale newLocale) async {
    // If the language is already correct, do nothing.
    if (_locale == newLocale) return;

    _locale = newLocale;

    // 1. Save the new language to local storage
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', _locale.languageCode);

    // 2. Notify all listening widgets to rebuild
    notifyListeners();
  }

  void loadLocale() async {
    // 1. Read from local storage
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // 2. Check for a SAVED language first
    String? savedLanguageCode = prefs.getString('language_code');

    if (savedLanguageCode != null) {
      // If the user has a saved preference, use it.
      _locale = Locale(savedLanguageCode);
    } else {
      // 3. If no saved preference, use the DEVICE SYSTEM locale.
      // We get the 'languageCode' (e.g., "en", "ar") from the system's Locale object.
      _locale = Locale(ui.PlatformDispatcher.instance.locale.languageCode);
    }

    // 4. Notify listeners that we've loaded the initial language
    notifyListeners();
  }
}
