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
  void requestAddress(double lat, double lng, String unknownAddressText) {
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
      _resolveAddress(lat, lng, key, unknownAddressText);
    });
  }

  /// Resolve address via reverse geocoding
  Future<void> _resolveAddress(
    double lat,
    double lng,
    String key,
    String unknownAddressText,
  ) async {
    _isLoading = true;

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

        final street = p.street?.trim();
        final area = p.subLocality?.trim();
        final city = p.locality?.trim();
        final admin = p.administrativeArea?.trim();
        final country = p.country?.trim();

        final parts = [
          if (street != null && street.isNotEmpty) street,
          //if (area != null && area.isNotEmpty) area,
          //if (city != null && city.isNotEmpty) city,
          //if (admin != null && admin.isNotEmpty) admin,
          //if (country != null && country.isNotEmpty) country,
        ];

        final text = parts.isNotEmpty ? parts.join(", ") : unknownAddressText;

        _cache[key] = text;
        _currentAddress = text;
      }
    } catch (e) {
      _currentAddress = "Unknown location";
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Get address as a Future<String?> for a latitude/longitude pair.
  /// This is convenient for use with FutureBuilder.
  Future<String?> getAddress(
    double lat,
    double lng,
    String unknownAddressText,
  ) async {
    final key = "$lat,$lng";

    // If cached, return immediately
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    // Debounce (wait 600ms before calling geocode)
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _resolveAddress(lat, lng, key, unknownAddressText);
    });
    return _cache[key] ?? _currentAddress;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
