import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences? _prefs;

  static const String _keyRadiusKm = 'notification_radius_km';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLocationLat = 'user_location_lat';
  static const String _keyLocationLng = 'user_location_lng';
  static const String _keyLocationLabel = 'user_location_label';

  static Future<PreferencesService> create() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return PreferencesService(prefs);
    } catch (e) {
      // Return a service with null prefs that will use defaults
      return PreferencesService(null);
    }
  }

  double getRadiusKm() {
    return _prefs?.getDouble(_keyRadiusKm) ?? 150.0;
  }

  Future<void> setRadiusKm(double value) async {
    await _prefs?.setDouble(_keyRadiusKm, value);
  }

  ThemeMode getThemeMode() {
    final raw = _prefs?.getString(_keyThemeMode);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await _prefs?.setString(_keyThemeMode, value);
  }

  SavedLocation? getSavedLocation() {
    if (_prefs == null) return null;
    
    final lat = _prefs!.getDouble(_keyLocationLat);
    final lng = _prefs!.getDouble(_keyLocationLng);
    final label = _prefs!.getString(_keyLocationLabel);

    if (lat == null || lng == null) {
      return null;
    }

    return SavedLocation(
      latitude: lat,
      longitude: lng,
      label: label ?? 'Unknown Location',
    );
  }

  Future<void> setLocation({
    required double latitude,
    required double longitude,
    required String label,
  }) async {
    await _prefs?.setDouble(_keyLocationLat, latitude);
    await _prefs?.setDouble(_keyLocationLng, longitude);
    await _prefs?.setString(_keyLocationLabel, label);
  }

  Future<void> clearAll() async {
    await _prefs?.clear();
  }
}

class SavedLocation {
  SavedLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;
}
