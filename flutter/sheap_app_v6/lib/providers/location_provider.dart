import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationProvider with ChangeNotifier {
  String _searchQuery = "";
  Position? _currentPosition;
  String? _currentAddress;
  bool _isLoading = true;
  bool _permissionDenied = false;
  bool _serviceEnabled = false; // New state to track GPS status

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<ServiceStatus>? _serviceStatusStream; // New Subscription

  // Getters
  Position? get currentPosition => _currentPosition;
  String? get currentAddress => _currentAddress;
  bool get isLoading => _isLoading;
  bool get permissionDenied => _permissionDenied;
  bool get serviceEnabled => _serviceEnabled;
  String get searchQuery => _searchQuery;

  Locale? _lastLocale;

  // 1. Initialize
  Future<void> initializeLocation(Locale appLocale) async {
    _lastLocale = appLocale;

    // Check initial status
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();

    // Start listening to GPS toggle events (On/Off)
    _listenToServiceStatus();

    if (!_serviceEnabled) {
      _isLoading = false;
      notifyListeners();
      return; // Stop here if GPS is off
    }

    // Check Permissions
    bool hasPermission = await _checkPermissions();
    if (hasPermission) {
      _startTracking();
    } else {
      _isLoading = false;
      _permissionDenied = true;
      notifyListeners();
    }
  }

  // 2. Listen for GPS Toggle (The new requirement)
  void _listenToServiceStatus() {
    _serviceStatusStream?.cancel();
    _serviceStatusStream = Geolocator.getServiceStatusStream().listen((
      ServiceStatus status,
    ) {
      final isEnabled = (status == ServiceStatus.enabled);
      _serviceEnabled = isEnabled;

      if (isEnabled) {
        // If user just turned GPS ON, try to start tracking automatically
        _isLoading = true;
        notifyListeners();
        _checkPermissions().then((hasPermission) {
          if (hasPermission) {
            _startTracking();
          }
        });
      } else {
        // If user turned GPS OFF, stop tracking and clear state
        _stopTracking();
        notifyListeners();
      }
    });
  }

  // 3. Permission Logic (Unchanged)
  Future<bool> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  // 4. Start Live Tracking
  void _startTracking() {
    _permissionDenied = false;
    _isLoading = true;
    notifyListeners(); // Show loading indicator

    _positionStream?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _currentPosition = position;
            _isLoading = false;
            notifyListeners();

            // Fetch address if we have a locale
            if (_lastLocale != null) {
              _updateAddress(position, _lastLocale!);
            }
          },
          onError: (e) {
            print("Location Stream Error: $e");
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _currentPosition = null;
    _currentAddress = null;
    _isLoading = false;
  }

  // 5. Geocoding (Unchanged)
  Future<void> _updateAddress(Position position, Locale locale) async {
    try {
      // Simple optimization: Don't re-geocode if distance is small could go here
      final String localeIdentifier = locale.toString();
      try {
        await setLocaleIdentifier(localeIdentifier);
      } catch (_) {}

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String city = place.locality != null ? "${place.locality}" : "";
        String district = place.subLocality != null
            ? "${place.subLocality}, "
            : "";
        String finalAddr = "$district$city";
        if (finalAddr.isEmpty) finalAddr = city;

        _currentAddress = finalAddr;
        notifyListeners();
      }
    } catch (e) {
      print("Geocoding Error: $e");
    }
  }

  void refreshAddressLocale(Locale newLocale) {
    _lastLocale = newLocale;
    if (_currentPosition != null) {
      _updateAddress(_currentPosition!, newLocale);
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners(); // This triggers UI updates automatically!
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _serviceStatusStream?.cancel();
    super.dispose();
  }
}
