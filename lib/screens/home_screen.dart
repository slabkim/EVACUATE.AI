import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

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
  });

  final String userLabel;
  final String eventLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
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
            const Text(
              'Lihat peta penuh',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
            gradient: LinearGradient(
              colors: isDark
                  ? <Color>[const Color(0xFF2F2023), const Color(0xFF1E1215)]
                  : <Color>[const Color(0xFFEDEBEB), const Color(0xFFD7D2D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GridPainter(
                      color: isDark ? const Color(0x33EC1337) : const Color(0x22EC1337),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 70,
                left: 110,
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _TagPeta(text: 'Anda'),
                  ],
                ),
              ),
              Positioned(
                top: 90,
                right: 95,
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bolt,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _TagPeta(text: 'Episentrum'),
                  ],
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
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
            ],
          ),
        ),
      ],
    );
  }
}

class _TagPeta extends StatelessWidget {
  const _TagPeta({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xCC221013) : const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8;
    const gap = 18.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.color != color;
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
