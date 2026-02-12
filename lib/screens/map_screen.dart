import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/earthquake_event.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/impact_radius.dart';

const double _markerHeight = 72;
const double _userMarkerWidth = 160;
const double _eventMarkerWidth = 180;
const double _markerDotSize = 6;

Alignment _anchorForDot({
  required double width,
  required double height,
  required double dotSize,
}) {
  return Marker.computePixelAlignment(
    width: width,
    height: height,
    left: width / 2,
    top: height - (dotSize / 2),
  );
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _didLoadInitial = false;
  int? _focusedEventIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadInitial) {
      return;
    }
    _didLoadInitial = true;
    unawaited(_loadFeed(context.read<AppState>().selectedMapFeed));
  }

  Future<void> _loadFeed(
    EarthquakeFeedCategory feed, {
    bool forceRefresh = false,
  }) async {
    final appState = context.read<AppState>();
    if (mounted) {
      setState(() {
        _focusedEventIndex = null;
      });
    }
    await appState.loadMapFeed(feed: feed, forceRefresh: forceRefresh);
    final events = appState.mapFeedEvents;
    if (events.isNotEmpty) {
      _focusEvent(events, 0, zoom: 5.2);
    }
  }

  void _focusEvent(
    List<EarthquakeEvent> events,
    int index, {
    double zoom = 6.1,
  }) {
    if (index < 0 || index >= events.length) {
      return;
    }
    final event = events[index];
    _mapController.move(LatLng(event.eqLat, event.eqLng), zoom);
    if (!mounted) {
      return;
    }
    setState(() {
      _focusedEventIndex = index;
    });
  }

  EarthquakeEvent? _focusedEvent(List<EarthquakeEvent> events) {
    final index = _focusedEventIndex;
    if (index == null || index < 0 || index >= events.length) {
      return null;
    }
    return events[index];
  }

  String _feedDescription(EarthquakeFeedCategory feed) {
    switch (feed) {
      case EarthquakeFeedCategory.latest:
        return 'Sumber: autogempa.json (1 event terbaru).';
      case EarthquakeFeedCategory.strong:
        return 'Sumber: gempaterkini.json (M 5.0+).';
      case EarthquakeFeedCategory.felt:
        return 'Sumber: gempadirasakan.json (event dirasakan).';
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${_two(local.day)}/${_two(local.month)}/${local.year} ${_two(local.hour)}:${_two(local.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final events = appState.mapFeedEvents;
        final latestEvent = events.isEmpty ? null : events.first;
        final focusedEvent = _focusedEvent(events) ?? latestEvent;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final userLatLng = LatLng(appState.userLat, appState.userLng);
        final focusLatLng = focusedEvent == null
            ? null
            : LatLng(focusedEvent.eqLat, focusedEvent.eqLng);
        final impactRadiusKm = focusedEvent == null
            ? null
            : estimateImpactRadiusKm(
                magnitude: focusedEvent.magnitude,
                depthKm: focusedEvent.depthKm,
              );

        final markers = <Marker>[
          Marker(
            point: userLatLng,
            width: _userMarkerWidth,
            height: _markerHeight,
            alignment: _anchorForDot(
              width: _userMarkerWidth,
              height: _markerHeight,
              dotSize: _markerDotSize,
            ),
            child: _MapPin(
              color: Colors.blue,
              icon: Icons.person_pin_circle,
              label:
                  'Anda (${appState.userLat.toStringAsFixed(2)}, ${appState.userLng.toStringAsFixed(2)})',
              dotSize: _markerDotSize,
            ),
          ),
          ...events.asMap().entries.map((entry) {
            final index = entry.key;
            final event = entry.value;
            final isFocused = index == _focusedEventIndex;
            final isPrimary = index == 0;
            final color = isFocused
                ? Colors.lightBlueAccent
                : (isPrimary ? AppTheme.primary : Colors.orange);
            final icon = isPrimary ? Icons.bolt : Icons.location_on;
            final label = isPrimary
                ? 'Terbaru M${event.magnitude.toStringAsFixed(1)}'
                : 'M${event.magnitude.toStringAsFixed(1)}';
            return Marker(
              point: LatLng(event.eqLat, event.eqLng),
              width: _eventMarkerWidth,
              height: _markerHeight,
              alignment: _anchorForDot(
                width: _eventMarkerWidth,
                height: _markerHeight,
                dotSize: _markerDotSize,
              ),
              child: _MapPin(
                color: color,
                icon: icon,
                label: label,
                dotSize: _markerDotSize,
              ),
            );
          }),
        ];

        final circles = <CircleMarker>[
          if (focusLatLng != null && impactRadiusKm != null)
            CircleMarker(
              point: focusLatLng,
              radius: impactRadiusKm * 1000,
              useRadiusInMeter: true,
              color: AppTheme.primary.withOpacity(0.18),
              borderColor: AppTheme.primary.withOpacity(0.55),
              borderStrokeWidth: 2,
            ),
        ];

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Peta Gempa',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh data kategori ini',
                      onPressed: appState.isLoadingMapFeed
                          ? null
                          : () => unawaited(
                                _loadFeed(
                                  appState.selectedMapFeed,
                                  forceRefresh: true,
                                ),
                              ),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Pilih kategori gempa BMKG lalu tap item di daftar untuk fokus ke titik pada peta.',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: EarthquakeFeedCategory.values
                      .map(
                        (feed) => ChoiceChip(
                          label: Text(feed.label),
                          selected: appState.selectedMapFeed == feed,
                          onSelected: (_) => unawaited(_loadFeed(feed)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  _feedDescription(appState.selectedMapFeed),
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: focusLatLng ?? userLatLng,
                        initialZoom: focusLatLng == null ? 6.0 : 5.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.drag |
                              InteractiveFlag.pinchZoom |
                              InteractiveFlag.doubleTapZoom,
                        ),
                      ),
                      children: <Widget>[
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.evacuateai',
                        ),
                        if (circles.isNotEmpty) CircleLayer(circles: circles),
                        MarkerLayer(markers: markers),
                      ],
                    ),
                  ),
                ),
                if (appState.mapFeedErrorMessage != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    appState.mapFeedErrorMessage!,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (appState.isLoadingMapFeed && events.isEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Daftar Lokasi Gempa',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (events.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: Text(
                      appState.isLoadingMapFeed
                          ? 'Memuat data gempa...'
                          : 'Belum ada data gempa pada kategori ini.',
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ...events.take(40).toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final event = entry.value;
                    final isFocused = index == _focusedEventIndex;
                    final subtitle =
                        'M${event.magnitude.toStringAsFixed(1)} | ${event.depthKm.toStringAsFixed(0)} km | ${_formatDateTime(event.dateTime)}';
                    return InkWell(
                      onTap: () => _focusEvent(events, index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isFocused
                              ? AppTheme.primary.withOpacity(0.12)
                              : (isDark ? AppTheme.surfaceDark : Colors.white),
                          border: Border.all(
                            color: isFocused
                                ? AppTheme.primary
                                : (isDark ? Colors.white10 : Colors.black12),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              index == 0 ? Icons.bolt : Icons.place,
                              color: index == 0 ? AppTheme.primary : Colors.orange,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    event.wilayah,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).hintColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if ((event.dirasakan ?? '').trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Dirasakan: ${event.dirasakan}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).hintColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.color,
    required this.icon,
    required this.label,
    required this.dotSize,
  });

  final Color color;
  final IconData icon;
  final String label;
  final double dotSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 2),
            Container(
              constraints: const BoxConstraints(maxWidth: 150),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.68),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
