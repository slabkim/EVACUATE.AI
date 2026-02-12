import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

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

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final event = appState.latestEvent;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final userLatLng = LatLng(appState.userLat, appState.userLng);
        final eventLatLng =
            event == null ? null : LatLng(event.eqLat, event.eqLng);
        final String eventLabel;
        if (event == null) {
          eventLabel = 'Menunggu episentrum';
        } else {
          eventLabel =
              'Episentrum (${event.eqLat.toStringAsFixed(2)}, ${event.eqLng.toStringAsFixed(2)})';
        }
        final impactRadiusKm = event == null
            ? null
            : estimateImpactRadiusKm(
                magnitude: event.magnitude,
                depthKm: event.depthKm,
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
          if (eventLatLng != null)
            Marker(
              point: eventLatLng,
              width: _eventMarkerWidth,
              height: _markerHeight,
              alignment: _anchorForDot(
                width: _eventMarkerWidth,
                height: _markerHeight,
                dotSize: _markerDotSize,
              ),
              child: _MapPin(
                color: AppTheme.primary,
                icon: Icons.bolt,
                label: eventLabel,
                dotSize: _markerDotSize,
              ),
            ),
        ];
        final circles = <CircleMarker>[
          if (eventLatLng != null && impactRadiusKm != null)
            CircleMarker(
              point: eventLatLng,
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
                Text(
                  'Peta Gempa',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Visualisasi lokasi Anda dan episentrum gempa terbaru.',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
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
                      options: MapOptions(
                        initialCenter: eventLatLng ?? userLatLng,
                        initialZoom: eventLatLng == null ? 6.0 : 5.0,
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
                const SizedBox(height: 14),
                if (event != null)
                  Text(
                    'Wilayah: ${event.wilayah}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
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
