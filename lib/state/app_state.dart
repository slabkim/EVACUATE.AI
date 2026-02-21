import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/earthquake_event.dart';
import '../models/emergency_alert_payload.dart';
import '../models/risk_result.dart';
import '../services/api_client.dart';
import '../services/audio_service.dart';
import '../services/fcm_service.dart';
import '../services/location_service.dart';
import '../services/preferences_service.dart';

enum EarthquakeFeedCategory { latest, strong, felt }

extension EarthquakeFeedCategoryX on EarthquakeFeedCategory {
  String get label {
    switch (this) {
      case EarthquakeFeedCategory.latest:
        return 'Gempa Terkini';
      case EarthquakeFeedCategory.strong:
        return 'M 5.0+';
      case EarthquakeFeedCategory.felt:
        return 'Dirasakan';
    }
  }

  String get feedParam {
    switch (this) {
      case EarthquakeFeedCategory.latest:
        return 'autogempa';
      case EarthquakeFeedCategory.strong:
        return 'm5';
      case EarthquakeFeedCategory.felt:
        return 'dirasakan';
    }
  }

  int get defaultLimit {
    switch (this) {
      case EarthquakeFeedCategory.latest:
        return 1;
      case EarthquakeFeedCategory.strong:
      case EarthquakeFeedCategory.felt:
        return 100;
    }
  }
}

class AppState extends ChangeNotifier {
  static const double _homeNearbyRadiusKm = 500;

  AppState({
    required ApiClient apiClient,
    required LocationService locationService,
    required FcmService fcmService,
    required AudioService audioService,
    required PreferencesService preferencesService,
  }) : _apiClient = apiClient,
       _locationService = locationService,
       _fcmService = fcmService,
       _audioService = audioService,
       _preferencesService = preferencesService;

  final ApiClient _apiClient;
  final LocationService _locationService;
  final FcmService _fcmService;
  final AudioService _audioService;
  final PreferencesService _preferencesService;

  final StreamController<EmergencyAlertPayload> _alertController =
      StreamController<EmergencyAlertPayload>.broadcast();
  final List<ChatMessage> _messages = <ChatMessage>[];
  final List<String> _nearbyReports = <String>[];

  bool _initialized = false;
  bool _isInitializing = false;
  bool _isLoadingHome = false;
  bool _isLoadingMapFeed = false;
  bool _isSendingMessage = false;
  bool _hasUnreadNotifications = false;
  int _selectedTab = 0;
  EarthquakeFeedCategory _selectedMapFeed = EarthquakeFeedCategory.felt;
  ThemeMode _themeMode = ThemeMode.system;

  UserLocation? _userLocation;
  EarthquakeEvent? _latestEvent;
  List<EarthquakeEvent> _recentEvents = <EarthquakeEvent>[];
  final Map<EarthquakeFeedCategory, List<EarthquakeEvent>> _mapFeedEvents =
      <EarthquakeFeedCategory, List<EarthquakeEvent>>{
        EarthquakeFeedCategory.latest: <EarthquakeEvent>[],
        EarthquakeFeedCategory.strong: <EarthquakeEvent>[],
        EarthquakeFeedCategory.felt: <EarthquakeEvent>[],
      };
  RiskResult? _riskResult;
  double? _distanceKm;
  String? _mapFeedErrorMessage;
  String? _errorMessage;

  Stream<EmergencyAlertPayload> get alertStream => _alertController.stream;
  bool get isInitializing => _isInitializing;
  bool get isLoadingHome => _isLoadingHome;
  bool get isLoadingMapFeed => _isLoadingMapFeed;
  bool get isSendingMessage => _isSendingMessage;
  bool get hasUnreadNotifications => _hasUnreadNotifications;
  int get selectedTab => _selectedTab;
  EarthquakeFeedCategory get selectedMapFeed => _selectedMapFeed;
  ThemeMode get themeMode => _themeMode;
  List<ChatMessage> get messages => List<ChatMessage>.unmodifiable(_messages);
  List<String> get nearbyReports => List<String>.unmodifiable(_nearbyReports);
  EarthquakeEvent? get latestEvent => _latestEvent;
  List<EarthquakeEvent> get recentEvents =>
      List<EarthquakeEvent>.unmodifiable(_recentEvents);
  List<EarthquakeEvent> get mapFeedEvents => List<EarthquakeEvent>.unmodifiable(
    _mapFeedEvents[_selectedMapFeed] ?? <EarthquakeEvent>[],
  );
  RiskResult? get riskResult => _riskResult;
  double? get distanceKm => _distanceKm;
  String? get mapFeedErrorMessage => _mapFeedErrorMessage;
  String? get errorMessage => _errorMessage;

  String get locationLabel => _userLocation?.label ?? 'Jakarta Selatan, ID';
  double get userLat => _userLocation?.latitude ?? -6.2088;
  double get userLng => _userLocation?.longitude ?? 106.8456;

  String get statusKesiagaan {
    final score = _riskResult?.riskScore ?? 0;
    final level = _riskResult?.riskLevel.toUpperCase() ?? '';
    if (level == 'EKSTREM' || level == 'TINGGI' || score >= 70) {
      return 'PERINGATAN';
    }
    if (level == 'SEDANG' || score >= 40) {
      return 'WASPADA';
    }
    return 'AMAN';
  }

  Future<void> initialize() async {
    if (_initialized || _isInitializing) {
      return;
    }
    _isInitializing = true;
    notifyListeners();

    try {
      // Load saved settings first
      _themeMode = _preferencesService.getThemeMode();
      
      // Load saved location (fallback if GPS unavailable)
      try {
        final savedLocation = _preferencesService.getSavedLocation();
        if (savedLocation != null) {
          _userLocation = UserLocation(
            latitude: savedLocation.latitude,
            longitude: savedLocation.longitude,
            label: savedLocation.label,
          );
          notifyListeners();
        }
      } catch (locationError) {
        // If saved location is corrupted, just skip it
        // GPS will provide fresh location
        print('Failed to load saved location: $locationError');
      }
      
      await _fcmService.initialize(onNotificationTap: _handleNotificationTap);
      await _resolveLocation();
      await refreshDashboard();
      await _registerDevice();
      _seedInitialMessages();
      _initialized = true;
    } catch (error) {
      _errorMessage = 'Inisialisasi gagal: $error';
      _seedInitialMessages();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> _resolveLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        _userLocation = location;
        notifyListeners();
        
        // Save location to preferences for future use
        unawaited(
          _preferencesService.setLocation(
            latitude: location.latitude,
            longitude: location.longitude,
            label: location.label,
          ),
        );
      }
    } catch (e) {
      // If location fails, just continue with saved location
      // which was already loaded in initialize()
      print('Failed to resolve location: $e');
    }
  }

  Future<void> _registerDevice() async {
    final token = await _fcmService.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    if (kDebugMode) {
      debugPrint('FCM token terdeteksi (debug): ${_maskToken(token)}');
    }

    await _apiClient.registerDevice(
      token: token,
      platform: _platformLabel(),
      lat: userLat,
      lng: userLng,
    );
  }

  String _platformLabel() {
    final platform = defaultTargetPlatform;
    switch (platform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return 'desktop';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  String _maskToken(String token) {
    if (token.length <= 16) {
      return token;
    }
    final prefix = token.substring(0, 8);
    final suffix = token.substring(token.length - 8);
    return '$prefix...$suffix';
  }

  Future<void> refreshDashboard() async {
    _isLoadingHome = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final events = await _apiClient.getEarthquakeEvents(
        limit: 200,
        feed: EarthquakeFeedCategory.felt.feedParam,
      );
      if (events.isEmpty) {
        _latestEvent = null;
        _recentEvents = <EarthquakeEvent>[];
        _distanceKm = null;
        _riskResult = null;
        _errorMessage = 'Belum ada data gempa dirasakan dari BMKG.';
        return;
      }
      _recentEvents = events;

      final nearest = _findNearestEventWithinRadius(
        events: events,
        maxRadiusKm: _homeNearbyRadiusKm,
      );
      if (nearest == null) {
        _latestEvent = null;
        _distanceKm = null;
        _riskResult = null;
        _errorMessage =
            'Tidak ada gempa dirasakan dalam radius ${_homeNearbyRadiusKm.toStringAsFixed(0)} km dari lokasi Anda.';
        return;
      }

      final event = nearest.event;
      final distance = nearest.distanceKm;
      final risk = await _apiClient.scoreRisk(
        userLat: userLat,
        userLng: userLng,
        eqLat: event.eqLat,
        eqLng: event.eqLng,
        magnitude: event.magnitude,
        depthKm: event.depthKm,
      );

      _latestEvent = event;
      _distanceKm = distance;
      _riskResult = risk;
      _mapFeedEvents[EarthquakeFeedCategory.felt] = events;
      _prependReport(
        'M${event.magnitude.toStringAsFixed(1)} ${event.wilayah} '
        '(${distance.toStringAsFixed(0)} km)',
      );
    } catch (error) {
      _errorMessage = 'Gagal memuat data gempa: $error';
    } finally {
      _isLoadingHome = false;
      notifyListeners();
    }
  }

  Future<void> loadMapFeed({
    EarthquakeFeedCategory? feed,
    bool forceRefresh = false,
  }) async {
    final targetFeed = feed ?? _selectedMapFeed;
    _selectedMapFeed = targetFeed;
    final cached = _mapFeedEvents[targetFeed] ?? <EarthquakeEvent>[];
    if (!forceRefresh && cached.isNotEmpty) {
      _mapFeedErrorMessage = null;
      notifyListeners();
      return;
    }

    _isLoadingMapFeed = true;
    _mapFeedErrorMessage = null;
    notifyListeners();

    try {
      final events = await _apiClient.getEarthquakeEvents(
        limit: targetFeed.defaultLimit,
        feed: targetFeed.feedParam,
      );
      _mapFeedEvents[targetFeed] = events;
      if (targetFeed == EarthquakeFeedCategory.felt) {
        _recentEvents = events;
      }
    } catch (error) {
      _mapFeedErrorMessage = 'Gagal memuat data peta: $error';
      _mapFeedEvents[targetFeed] = <EarthquakeEvent>[];
    } finally {
      _isLoadingMapFeed = false;
      notifyListeners();
    }
  }

  _NearbyEvent? _findNearestEventWithinRadius({
    required List<EarthquakeEvent> events,
    required double maxRadiusKm,
  }) {
    _NearbyEvent? nearest;
    for (final event in events) {
      final distance = _locationService.distanceKm(
        fromLat: userLat,
        fromLng: userLng,
        toLat: event.eqLat,
        toLng: event.eqLng,
      );
      if (distance > maxRadiusKm) {
        continue;
      }
      if (nearest == null || distance < nearest.distanceKm) {
        nearest = _NearbyEvent(event: event, distanceKm: distance);
      }
    }
    return nearest;
  }

  void _prependReport(String report) {
    final isNewReport = !_nearbyReports.contains(report);
    _nearbyReports.remove(report);
    _nearbyReports.insert(0, report);
    if (_nearbyReports.length > 8) {
      _nearbyReports.removeLast();
    }
    if (isNewReport && _initialized && _selectedTab != 3) {
      _hasUnreadNotifications = true;
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSendingMessage) {
      return;
    }

    _messages.add(
      ChatMessage(
        id: 'user-${DateTime.now().millisecondsSinceEpoch}',
        text: trimmed,
        isUser: true,
        createdAt: DateTime.now(),
      ),
    );
    _isSendingMessage = true;
    notifyListeners();

    try {
      final start = _messages.length > 12 ? _messages.length - 12 : 0;
      final history = _messages.skip(start).map((m) => m.toJson()).toList();

      final reply = await _apiClient.sendChat(
        message: trimmed,
        history: history,
        latestEarthquake: _latestEvent?.toJson(),
        risk: _riskResult?.toJson(),
        userLocation: <String, dynamic>{
          'lat': userLat,
          'lng': userLng,
          'label': locationLabel,
        },
      );

      _messages.add(
        ChatMessage(
          id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
          text: reply,
          isUser: false,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {
      _messages.add(
        ChatMessage(
          id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
          text:
              'Maaf, layanan AI sedang sibuk. Tetap tenang, lakukan Jatuhkan Diri, Lindungi Kepala, dan Bertahan.',
          isUser: false,
          createdAt: DateTime.now(),
        ),
      );
    } finally {
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _messages.clear();
    _seedInitialMessages();
    notifyListeners();
  }

  void _seedInitialMessages() {
    if (_messages.isNotEmpty) {
      return;
    }
    _messages.add(
      ChatMessage(
        id: 'welcome',
        text:
            'Saya AI Darurat. Jelaskan kondisi Anda, saya akan memberi panduan gempa secara ringkas.',
        isUser: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  void setSelectedTab(int index) {
    _selectedTab = index;
    if (index == 3 && _hasUnreadNotifications) {
      _hasUnreadNotifications = false;
    }
    notifyListeners();
  }

  void markNotificationsRead() {
    if (!_hasUnreadNotifications) {
      return;
    }
    _hasUnreadNotifications = false;
    notifyListeners();
  }

  void cycleThemeMode() {
    if (_themeMode == ThemeMode.system) {
      _themeMode = ThemeMode.light;
    } else if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
    unawaited(_preferencesService.setThemeMode(_themeMode));
  }

  void triggerEmergencyFromCurrent() {
    if (_latestEvent == null || _riskResult == null) {
      return;
    }
    final payload = EmergencyAlertPayload(
      event: _latestEvent!,
      risk: _riskResult!,
      distanceKm: _distanceKm ?? 0,
    );
    if ((_distanceKm ?? 0) <= 100) {
      unawaited(_audioService.playSiren());
    }
    _alertController.add(payload);
  }

  void stopSiren() {
    unawaited(_audioService.stopAll());
  }

  void testEmergencyAlert() {
    final testEvent = EarthquakeEvent(
      dateTime: DateTime.now(),
      magnitude: 6.8,
      depthKm: 12.0,
      wilayah: 'Jawa Barat (Simulasi Test)',
      eqLat: -7.2245,
      eqLng: 107.9068,
    );

    final testRisk = RiskResult(
      riskScore: 85,
      riskLevel: 'TINGGI',
      rekomendasi:
          'TEST: Segera lakukan Jatuhkan Diri, Lindungi Kepala, Bertahan, dan jauhi kaca atau benda berat.',
    );

    final payload = EmergencyAlertPayload(
      event: testEvent,
      risk: testRisk,
      distanceKm: 28.5,
    );

    // Show local notification as well
    unawaited(
      _fcmService.showLocalNotification(
        title: 'âš ï¸ PERINGATAN KRITIS (TEST)',
        body: 'Gempa M 6.8 terdeteksi di Jawa Barat. Segera berlindung!',
        payload: {
          'magnitude': 6.8,
          'depth': 12,
          'wilayah': 'Jawa Barat (Simulasi Test)',
          'riskLevel': 'TINGGI',
          'riskScore': 85,
          'distanceKm': 28.5,
          'time': testEvent.dateTime.toIso8601String(),
          'eqLat': -7.2245,
          'eqLng': 107.9068,
        },
      ),
    );

    unawaited(_audioService.playSiren());
    _alertController.add(payload);
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final event = EarthquakeEvent(
      dateTime: DateTime.tryParse('${data['time']}') ?? DateTime.now(),
      magnitude: _toDouble(data['magnitude']),
      depthKm: _toDouble(data['depth']),
      wilayah: '${data['wilayah'] ?? 'Dekat lokasi Anda'}',
      eqLat: _toDouble(data['eqLat']),
      eqLng: _toDouble(data['eqLng']),
    );

    final risk = RiskResult(
      riskScore: (_toDouble(data['riskScore']).round().clamp(0, 100) as num)
          .toInt(),
      riskLevel: '${data['riskLevel'] ?? 'TINGGI'}',
      rekomendasi:
          'Segera lakukan Jatuhkan Diri, Lindungi Kepala, Bertahan, dan jauhi kaca atau benda berat.',
    );

    final payload = EmergencyAlertPayload(
      event: event,
      risk: risk,
      distanceKm: _toDouble(data['distanceKm']),
    );
    if (_selectedTab != 3) {
      _hasUnreadNotifications = true;
      notifyListeners();
    }
    if (_toDouble(data['distanceKm']) <= 100) {
      unawaited(_audioService.playSiren());
    }
    _alertController.add(payload);
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  @override
  void dispose() {
    _alertController.close();
    unawaited(_fcmService.dispose());
    super.dispose();
  }
}

class _NearbyEvent {
  _NearbyEvent({required this.event, required this.distanceKm});

  final EarthquakeEvent event;
  final double distanceKm;
}

