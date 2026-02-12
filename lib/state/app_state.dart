import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/earthquake_event.dart';
import '../models/emergency_alert_payload.dart';
import '../models/risk_result.dart';
import '../services/api_client.dart';
import '../services/fcm_service.dart';
import '../services/location_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    required ApiClient apiClient,
    required LocationService locationService,
    required FcmService fcmService,
  })  : _apiClient = apiClient,
        _locationService = locationService,
        _fcmService = fcmService;

  final ApiClient _apiClient;
  final LocationService _locationService;
  final FcmService _fcmService;

  final StreamController<EmergencyAlertPayload> _alertController =
      StreamController<EmergencyAlertPayload>.broadcast();
  final List<ChatMessage> _messages = <ChatMessage>[];
  final List<String> _nearbyReports = <String>[];

  bool _initialized = false;
  bool _isInitializing = false;
  bool _isLoadingHome = false;
  bool _isSendingMessage = false;
  int _selectedTab = 0;
  ThemeMode _themeMode = ThemeMode.system;
  double _radiusKm = 150;

  UserLocation? _userLocation;
  EarthquakeEvent? _latestEvent;
  List<EarthquakeEvent> _recentEvents = <EarthquakeEvent>[];
  RiskResult? _riskResult;
  double? _distanceKm;
  String? _errorMessage;

  Stream<EmergencyAlertPayload> get alertStream => _alertController.stream;
  bool get isInitializing => _isInitializing;
  bool get isLoadingHome => _isLoadingHome;
  bool get isSendingMessage => _isSendingMessage;
  int get selectedTab => _selectedTab;
  ThemeMode get themeMode => _themeMode;
  List<ChatMessage> get messages => List<ChatMessage>.unmodifiable(_messages);
  List<String> get nearbyReports => List<String>.unmodifiable(_nearbyReports);
  EarthquakeEvent? get latestEvent => _latestEvent;
  List<EarthquakeEvent> get recentEvents =>
      List<EarthquakeEvent>.unmodifiable(_recentEvents);
  RiskResult? get riskResult => _riskResult;
  double? get distanceKm => _distanceKm;
  String? get errorMessage => _errorMessage;
  double get radiusKm => _radiusKm;

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
    final location = await _locationService.getCurrentLocation();
    if (location != null) {
      _userLocation = location;
      notifyListeners();
    }
  }

  Future<void> _registerDevice() async {
    final token = await _fcmService.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await _apiClient.registerDevice(
      token: token,
      platform: _platformLabel(),
      lat: userLat,
      lng: userLng,
      radiusKm: _radiusKm,
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
    return 'unknown';
  }

  Future<void> refreshDashboard() async {
    _isLoadingHome = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final latestEventFuture = _apiClient.getLatestEarthquake();
      final eventsFuture = _apiClient.getEarthquakeEvents(limit: 20);
      final event = await latestEventFuture;
      List<EarthquakeEvent> events;
      try {
        events = await eventsFuture;
      } catch (_) {
        events = <EarthquakeEvent>[event];
      }
      if (events.isEmpty) {
        events = <EarthquakeEvent>[event];
      }
      final distance = _locationService.distanceKm(
        fromLat: userLat,
        fromLng: userLng,
        toLat: event.eqLat,
        toLng: event.eqLng,
      );
      final risk = await _apiClient.scoreRisk(
        userLat: userLat,
        userLng: userLng,
        eqLat: event.eqLat,
        eqLng: event.eqLng,
        magnitude: event.magnitude,
        depthKm: event.depthKm,
      );

      _latestEvent = event;
      _recentEvents = events;
      _distanceKm = distance;
      _riskResult = risk;
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

  void _prependReport(String report) {
    _nearbyReports.remove(report);
    _nearbyReports.insert(0, report);
    if (_nearbyReports.length > 8) {
      _nearbyReports.removeLast();
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
      final history = _messages
          .skip(start)
          .map((m) => m.toJson())
          .toList();

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
  }

  void setRadiusKm(double value) {
    _radiusKm = value;
    notifyListeners();
    unawaited(_registerDevice());
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
