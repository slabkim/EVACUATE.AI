import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/impact_radius.dart';

const double _miniMarkerHeight = 46;
const double _miniDotSize = 6;

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

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onTapChatAi,
    required this.onTapChecklist,
  });

  final VoidCallback onTapChatAi;
  final VoidCallback onTapChecklist;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final event = appState.latestEvent;
        final risk = appState.riskResult;
        final distance = appState.distanceKm;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: <Widget>[
                _HeaderLokasi(label: appState.locationLabel),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: appState.refreshDashboard,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      children: <Widget>[
                        _KartuRisiko(
                          status: appState.statusKesiagaan,
                          riskScore: risk?.riskScore ?? 0,
                          rekomendasi: risk?.rekomendasi ??
                              'Sedang mengambil data BMKG terbaru.',
                          lastUpdate: event?.dateTime,
                        ),
                        const SizedBox(height: 16),
                        _SectionPeta(
                          userLabel: appState.locationLabel,
                          eventLabel: event?.wilayah ?? 'Menunggu data lokasi gempa',
                          isDark: isDark,
                          onTapFullMap: () => appState.setSelectedTab(1),
                          userLat: appState.userLat,
                          userLng: appState.userLng,
                          eventLat: event?.eqLat,
                          eventLng: event?.eqLng,
                          eventMagnitude: event?.magnitude,
                          eventDepthKm: event?.depthKm,
                        ),
                        const SizedBox(height: 16),
                        _StatistikGempa(
                          magnitude: event?.magnitude,
                          depthKm: event?.depthKm,
                          distanceKm: distance,
                        ),
                        const SizedBox(height: 16),
                        _AksiCepat(
                          onTapChatAi: onTapChatAi,
                          onTapChecklist: onTapChecklist,
                        ),
                        const SizedBox(height: 20),
                        _LaporanSekitar(reports: appState.nearbyReports),
                        if (appState.errorMessage != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            appState.errorMessage!,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (appState.isLoadingHome) ...<Widget>[
                          const SizedBox(height: 16),
                          const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderLokasi extends StatelessWidget {
  const _HeaderLokasi({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: background.withOpacity(0.95),
      child: Row(
        children: <Widget>[
          const Icon(Icons.location_on, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Lokasi Saat Ini',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).hintColor,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
          Stack(
            children: <Widget>[
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications),
              ),
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KartuRisiko extends StatelessWidget {
  const _KartuRisiko({
    required this.status,
    required this.riskScore,
    required this.rekomendasi,
    required this.lastUpdate,
  });

  final String status;
  final int riskScore;
  final String rekomendasi;
  final DateTime? lastUpdate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFEC1337), Color(0xFFAF1029)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x55EC1337),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Pembaruan Status',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  const Text(
                    'Skor Risiko',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$riskScore/100',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rekomendasi,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Text(
                'Sumber: BMKG Langsung',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _relativeTime(lastUpdate),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime? time) {
    if (time == null) {
      return 'Diperbarui baru saja';
    }
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      return 'Diperbarui baru saja';
    }
    if (diff.inMinutes < 60) {
      return 'Diperbarui ${diff.inMinutes} menit lalu';
    }
    return 'Diperbarui ${diff.inHours} jam lalu';
  }
}

class _SectionPeta extends StatelessWidget {
  const _SectionPeta({
    required this.userLabel,
    required this.eventLabel,
    required this.isDark,
    required this.onTapFullMap,
    required this.userLat,
    required this.userLng,
    required this.eventLat,
    required this.eventLng,
    required this.eventMagnitude,
    required this.eventDepthKm,
  });

  final String userLabel;
  final String eventLabel;
  final bool isDark;
  final VoidCallback onTapFullMap;
  final double userLat;
  final double userLng;
  final double? eventLat;
  final double? eventLng;
  final double? eventMagnitude;
  final double? eventDepthKm;

  @override
  Widget build(BuildContext context) {
    final userLatLng = LatLng(userLat, userLng);
    final eventLatLng =
        (eventLat == null || eventLng == null) ? null : LatLng(eventLat!, eventLng!);
    final impactRadiusKm =
        (eventLatLng == null || eventMagnitude == null || eventDepthKm == null)
            ? null
            : estimateImpactRadiusKm(
                magnitude: eventMagnitude!,
                depthKm: eventDepthKm!,
              );
    final markers = <Marker>[
      Marker(
        point: userLatLng,
        width: 120,
        height: _miniMarkerHeight,
        alignment: _anchorForDot(
          width: 120,
          height: _miniMarkerHeight,
          dotSize: _miniDotSize,
        ),
        child: const _MiniPin(
          color: Colors.blueAccent,
          label: 'Anda',
          dotSize: _miniDotSize,
        ),
      ),
      if (eventLatLng != null)
        Marker(
          point: eventLatLng,
          width: 140,
          height: _miniMarkerHeight,
          alignment: _anchorForDot(
            width: 140,
            height: _miniMarkerHeight,
            dotSize: _miniDotSize,
          ),
          child: const _MiniPin(
            color: AppTheme.primary,
            label: 'Episentrum',
            dotSize: _miniDotSize,
          ),
        ),
    ];
    final circles = <CircleMarker>[
      if (eventLatLng != null && impactRadiusKm != null)
        CircleMarker(
          point: eventLatLng,
          radius: impactRadiusKm * 1000,
          useRadiusInMeter: true,
          color: AppTheme.primary.withOpacity(0.16),
          borderColor: AppTheme.primary.withOpacity(0.5),
          borderStrokeWidth: 1.5,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Peta Kejadian',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            InkWell(
              onTap: onTapFullMap,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'Lihat peta penuh',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: <Widget>[
                FlutterMap(
                  options: MapOptions(
                    initialCenter: eventLatLng ?? userLatLng,
                    initialZoom: eventLatLng == null ? 5.2 : 5.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
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
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withOpacity(0.45)
                          : Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: Text(
                      '$userLabel -> $eventLabel',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniPin extends StatelessWidget {
  const _MiniPin({
    required this.color,
    required this.label,
    required this.dotSize,
  });

  final Color color;
  final String label;
  final double dotSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.expand(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xCC221013) : const Color(0xCCFFFFFF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatistikGempa extends StatelessWidget {
  const _StatistikGempa({
    required this.magnitude,
    required this.depthKm,
    required this.distanceKm,
  });

  final double? magnitude;
  final double? depthKm;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatItem(
            icon: Icons.show_chart,
            iconColor: AppTheme.primary,
            title: 'Magnitudo',
            value: magnitude == null ? '--' : magnitude!.toStringAsFixed(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatItem(
            icon: Icons.arrow_downward,
            iconColor: Colors.orange,
            title: 'Kedalaman',
            value: depthKm == null ? '--' : '${depthKm!.toStringAsFixed(0)} km',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatItem(
            icon: Icons.near_me,
            iconColor: Colors.green,
            title: 'Jarak',
            value: distanceKm == null ? '--' : '${distanceKm!.toStringAsFixed(0)} km',
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).hintColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AksiCepat extends StatelessWidget {
  const _AksiCepat({
    required this.onTapChatAi,
    required this.onTapChecklist,
  });

  final VoidCallback onTapChatAi;
  final VoidCallback onTapChecklist;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: <Widget>[
        InkWell(
          onTap: onTapChatAi,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x55EC1337),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                children: <Widget>[
                  Icon(Icons.smart_toy, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chat AI Darurat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onTapChecklist,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.checklist,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Checklist Keselamatan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LaporanSekitar extends StatelessWidget {
  const _LaporanSekitar({required this.reports});

  final List<String> reports;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Laporan Sekitar',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        if (reports.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Text(
              'Belum ada laporan lokal.',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ...reports.map(
            (report) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark ? AppTheme.surfaceDark : Colors.white,
                border:
                    Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      report,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
