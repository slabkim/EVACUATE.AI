import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/earthquake_event.dart';
import '../models/risk_result.dart';

class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:3000',
            );

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<EarthquakeEvent> getLatestEarthquake() async {
    final response = await _client.get(_uri('/api/bmkg/latest')).timeout(
          const Duration(seconds: 15),
        );
    final data = _decode(response);
    return EarthquakeEvent.fromJson(data['event'] as Map<String, dynamic>);
  }

  Future<List<EarthquakeEvent>> getEarthquakeEvents({
    int limit = 20,
    String? feed,
  }) async {
    final safeLimit = limit <= 0 ? 20 : limit;
    final feedQuery = (feed == null || feed.trim().isEmpty)
        ? ''
        : '&feed=${Uri.encodeQueryComponent(feed.trim())}';
    final response = await _client
        .get(_uri('/api/bmkg/list?limit=$safeLimit$feedQuery'))
        .timeout(const Duration(seconds: 15));
    final data = _decode(response);
    final rawEvents = data['events'];
    if (rawEvents is! List) {
      throw ApiException('Format daftar gempa tidak valid.');
    }

    final events = <EarthquakeEvent>[];
    for (final item in rawEvents) {
      if (item is Map) {
        events.add(
          EarthquakeEvent.fromJson(
            Map<String, dynamic>.from(item),
          ),
        );
      }
    }
    return List<EarthquakeEvent>.unmodifiable(events);
  }

  Future<RiskResult> scoreRisk({
    required double userLat,
    required double userLng,
    required double eqLat,
    required double eqLng,
    required double magnitude,
    required double depthKm,
  }) async {
    final payload = <String, dynamic>{
      'userLat': userLat,
      'userLng': userLng,
      'eqLat': eqLat,
      'eqLng': eqLng,
      'magnitude': magnitude,
      'depthKm': depthKm,
    };
    final response = await _client
        .post(
          _uri('/api/risk/score'),
          headers: <String, String>{
            'content-type': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    final data = _decode(response);
    return RiskResult.fromJson(data);
  }

  Future<void> registerDevice({
    required String token,
    required String platform,
    required double lat,
    required double lng,
  }) async {
    final response = await _client
        .post(
          _uri('/api/device/register'),
          headers: <String, String>{
            'content-type': 'application/json',
          },
          body: jsonEncode(
            <String, dynamic>{
              'token': token,
              'platform': platform,
              'lat': lat,
              'lng': lng,
            },
          ),
        )
        .timeout(const Duration(seconds: 15));

    _decode(response);
  }

  Future<String> sendChat({
    required String message,
    required List<Map<String, dynamic>> history,
    Map<String, dynamic>? latestEarthquake,
    Map<String, dynamic>? risk,
    Map<String, dynamic>? userLocation,
  }) async {
    final response = await _client
        .post(
          _uri('/api/chat'),
          headers: <String, String>{
            'content-type': 'application/json',
          },
          body: jsonEncode(
            <String, dynamic>{
              'message': message,
              'history': history,
              'latestEarthquake': latestEarthquake,
              'risk': risk,
              'userLocation': userLocation,
            },
          ),
        )
        .timeout(const Duration(seconds: 30));

    final data = _decode(response);
    return '${data['reply'] ?? 'Maaf, terjadi gangguan saat memproses pesan.'}';
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) {
      throw ApiException('Respon kosong dari server.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Format respon tidak valid.');
    }
    if (response.statusCode >= 400) {
      final message = decoded['error']?.toString() ??
          decoded['message']?.toString() ??
          'Terjadi kesalahan pada server.';
      throw ApiException(message);
    }
    return decoded;
  }

  @visibleForTesting
  String get baseUrl => _baseUrl;
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => 'ApiException: $message';
}
