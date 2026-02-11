import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final event = appState.latestEvent;
        final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: Center(
                          child: Icon(
                            Icons.map,
                            size: 160,
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.black.withOpacity(0.05),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 60,
                        top: 160,
                        child: _MapPin(
                          color: Colors.blue,
                          icon: Icons.person_pin_circle,
                          label:
                              'Anda (${appState.userLat.toStringAsFixed(2)}, ${appState.userLng.toStringAsFixed(2)})',
                        ),
                      ),
                      Positioned(
                        right: 60,
                        top: 90,
                        child: _MapPin(
                          color: AppTheme.primary,
                          icon: Icons.bolt,
                          label: event == null
                              ? 'Menunggu episentrum'
                              : 'Episentrum (${event.eqLat.toStringAsFixed(2)}, ${event.eqLng.toStringAsFixed(2)})',
                        ),
                      ),
                    ],
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
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 2),
        Container(
          constraints: const BoxConstraints(maxWidth: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          ),
        ),
      ],
    );
  }
}
