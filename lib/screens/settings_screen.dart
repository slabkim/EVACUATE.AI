import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Text(
                  'Pengaturan',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 14),
                _SettingCard(
                  isDark: isDark,
                  child: ListTile(
                    title: const Text(
                      'Mode Tema',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(_labelTheme(appState.themeMode)),
                    trailing: FilledButton(
                      onPressed: appState.cycleThemeMode,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                      child: const Text('Ubah'),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _SettingCard(
                  isDark: isDark,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Aturan Notifikasi Gempa',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Notifikasi dikirim otomatis jika:\n'
                          '• Gempa berada dalam radius 200 km dari lokasi Anda.\n'
                          '• Magnitudo gempa 5.0 atau lebih, tanpa memedulikan jarak.',
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _SettingCard(
                  isDark: isDark,
                  child: ListTile(
                    title: const Text(
                      'Refresh Data BMKG',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Ambil pembaruan gempa terbaru sekarang.'),
                    trailing: IconButton(
                      onPressed: appState.refreshDashboard,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _SettingCard(
                  isDark: isDark,
                  child: ListTile(
                    title: const Text(
                      'Test Peringatan',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Simulasi peringatan darurat gempa.'),
                    trailing: FilledButton(
                      onPressed: appState.testEmergencyAlert,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                      child: const Text('Test'),
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

  static String _labelTheme(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Mengikuti sistem';
      case ThemeMode.light:
        return 'Terang';
      case ThemeMode.dark:
        return 'Gelap';
    }
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.child,
    required this.isDark,
  });

  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: child,
    );
  }
}
