import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

class GeocodingProvider with ChangeNotifier {
  // Cache: "lat,long" -> address string
  final Map<String, String> _cache = {};

  // Debounce timer
  Timer? _debounce;

  // Last requested coordinate
  String? _lastRequestedKey;

  // Current resolved address
  String? _currentAddress;
  String? get currentAddress => _currentAddress;

  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // locale
  Locale _locale = const Locale('en');

  void updateLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;

    // Clear cache because cached addresses are in the old language
    _cache.clear();
  }

  /// Request address for a latitude/longitude pair.
  /// Uses debounce to prevent spamming the geocoding API.
  void requestAddress(double lat, double lng) {
    final key = "$lat,$lng";
    _lastRequestedKey = key;

    // If cached, return immediately
    if (_cache.containsKey(key)) {
      _currentAddress = _cache[key];

      return;
    }

    // Debounce (wait 600ms before calling geocode)
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _resolveAddress(lat, lng, key);
    });
  }

  /// Resolve address via reverse geocoding
  Future<void> _resolveAddress(double lat, double lng, String key) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Set locale if possible
      try {
        await setLocaleIdentifier(
          "${_locale.languageCode}_${_locale.countryCode}",
        );
      } catch (_) {}

      final placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final text =
            "${p.street}, ${p.locality}, ${p.administrativeArea}, ${p.country}";

        _cache[key] = text;
        _currentAddress = text;
      }
    } catch (e) {
      _currentAddress = "Unknown location";
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
