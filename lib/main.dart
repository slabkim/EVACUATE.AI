import 'dart:async';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/emergency_alert_payload.dart';
import 'screens/chat_screen.dart';
import 'screens/emergency_alert_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/settings_screen.dart';
import 'services/api_client.dart';
import 'services/audio_service.dart';
import 'services/fcm_service.dart';
import 'services/local_notif_service.dart';
import 'services/location_service.dart';
import 'services/preferences_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/app_bottom_nav.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    ui.DartPluginRegistrant.ensureInitialized();
    await Firebase.initializeApp();
    
    // Handle data-only messages by creating local notification with custom sound
    final title = message.notification?.title ?? message.data['title'] ?? 'Peringatan Gempa';
    final body = message.notification?.body ?? message.data['body'] ?? 'Terdapat pembaruan gempa';
    
    // Show notification with custom sound
    final localNotifService = LocalNotifService();
    await localNotifService.initialize((_) {}); // Empty callback for background
    await localNotifService.showForegroundNotification(
      title: title,
      body: body,
      payload: message.data,
    );
  } catch (e) {
    debugPrint('Background message handler error: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (_) {}

  runApp(const EvacuateAiApp());
}

class EvacuateAiApp extends StatefulWidget {
  const EvacuateAiApp({super.key});

  @override
  State<EvacuateAiApp> createState() => _EvacuateAiAppState();
}

class _EvacuateAiAppState extends State<EvacuateAiApp> {
  PreferencesService? _preferencesService;

  @override
  void initState() {
    super.initState();
    _initPreferences();
  }

  Future<void> _initPreferences() async {
    final prefs = await PreferencesService.create();
    if (mounted) {
      setState(() {
        _preferencesService = prefs;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_preferencesService == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState(
        apiClient: ApiClient(),
        locationService: LocationService(),
        fcmService: FcmService(LocalNotifService()),
        audioService: AudioService(),
        preferencesService: _preferencesService!,
      ),
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'EVACUATE.AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: appState.themeMode,
            home: const _AppShell(),
          );
        },
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  StreamSubscription<EmergencyAlertPayload>? _alertSubscription;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    final appState = context.read<AppState>();
    unawaited(appState.initialize());
    _alertSubscription = appState.alertStream.listen(_openEmergencyAlert);
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openEmergencyAlert(EmergencyAlertPayload payload) async {
    if (!mounted) {
      return;
    }
    final openChat = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EmergencyAlertScreen(payload: payload),
      ),
    );
    if (mounted) {
      context.read<AppState>().stopSiren();
    }
    if (openChat == true && mounted) {
      context.read<AppState>().setSelectedTab(2);
    }
  }

  void _showChecklist() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text(
                'Checklist Keselamatan Gempa',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 10),
              _ChecklistItem('1. Jatuhkan diri ke posisi aman.'),
              _ChecklistItem('2. Lindungi kepala dan leher.'),
              _ChecklistItem('3. Bertahan sampai guncangan berhenti.'),
              _ChecklistItem('4. Hindari lift, kaca, dan benda gantung.'),
              _ChecklistItem('5. Setelah aman, cek gas/listrik sebelum keluar.'),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final pages = <Widget>[
      HomeScreen(
        onTapChatAi: () => appState.setSelectedTab(2),
        onTapChecklist: _showChecklist,
      ),
      const MapScreen(),
      const ChatScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: appState.selectedTab,
          children: pages,
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: appState.selectedTab,
        onTap: appState.setSelectedTab,
      ),
      floatingActionButton: appState.statusKesiagaan == 'PERINGATAN'
          ? FloatingActionButton.extended(
              onPressed: appState.triggerEmergencyFromCurrent,
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.warning, color: Colors.white),
              label: const Text(
                'Lihat Peringatan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

