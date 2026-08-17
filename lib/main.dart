import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'constants/brand_constants.dart';
import 'config/api_config.dart';
import 'navigation/app_entry.dart';
import 'navigation/app_navigator.dart';
import 'screens/security_warning_modal.dart';
import 'services/ad_free_campaign_service.dart';
import 'services/ad_manager.dart';
import 'services/boot_store.dart';
import 'services/offline_pack_service.dart';
import 'services/smart_review_service.dart';
import 'services/announcement_service.dart';
import 'services/auth_service.dart';
import 'services/content_bank_service.dart';
import 'services/content_sync_service.dart';
import 'services/database_bootstrap.dart';
import 'services/database_service.dart';
import 'services/favorites_service.dart';
import 'services/last_study_session_service.dart';
import 'services/local_database.dart';
import 'services/notes_service.dart';
import 'services/exam_catalog_service.dart';
import 'services/kpss_preference_service.dart';
import 'services/theme_preference_service.dart';
import 'services/user_savings_insight_service.dart';
import 'services/daily_mini_exam_service.dart';
import 'services/network_security_service.dart';
import 'services/notification_preference_service.dart';
import 'services/notification_service.dart';
import 'services/orientation_policy.dart';
import 'services/play_billing_service.dart';
import 'services/practice_exam_service.dart';
import 'services/push_notification_service.dart';
import 'services/user_message_service.dart';
import 'theme/app_theme.dart';
import 'widgets/boot_splash_screen.dart';

void main() {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  unawaited(OrientationPolicy.apply());
  runApp(const KpssOdakApp());
}

class KpssOdakApp extends StatefulWidget {
  const KpssOdakApp({super.key});

  @override
  State<KpssOdakApp> createState() => _KpssOdakAppState();
}

class _KpssOdakAppState extends State<KpssOdakApp> with WidgetsBindingObserver {
  final NetworkSecurityService _networkSecurity = NetworkSecurityService();
  bool _isConnectionBlocked = false;
  bool _securityChecked = false;

  /// Auth hazır → hemen ana sayfa (ağır servisler arka planda).
  bool _bootReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService.instance.addListener(_onAuthChanged);
    unawaited(OrientationPolicy.apply());
    unawaited(_boot());
    unawaited(_checkNetworkSecurity());
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted || !_bootReady) return;
    final user = AuthService.instance.user;
    if (user != null) {
      DatabaseService.instance.setCurrentUser(user);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        unawaited(AppNavigator.consumePending());
      });
    }
    setState(() {});
  }

  @override
  void didChangeMetrics() {
    unawaited(OrientationPolicy.apply());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (AuthService.instance.isLocalGuest) {
        unawaited(AuthService.instance.ensureAnonymousSession());
      }
      unawaited(ExamCatalogService.instance.refresh());
      unawaited(NotificationService.instance.ensureScheduled());
    }
  }

  Future<void> _boot() async {
    final sw = Stopwatch()..start();
    try {
      if (await BootStore.exists()) {
        final snap = await BootStore.load();
        ThemePreferenceService.instance.applyBootSnapshot(snap);
        KpssPreferenceService.instance.applyBootSnapshot(snap);
        if (kDebugMode) {
          debugPrint('Boot fast-path: ${sw.elapsedMilliseconds}ms');
        }
        if (!mounted) return;
        setState(() => _bootReady = true);
        FlutterNativeSplash.remove();
        unawaited(_finishFullBoot());
      } else {
        // BootStore yok: onboarding'i hemen göster; ağır SharedPreferences arka planda.
        final defaults = BootSnapshot.defaults();
        ThemePreferenceService.instance.applyBootSnapshot(defaults);
        KpssPreferenceService.instance.applyBootSnapshot(defaults);
        if (kDebugMode) {
          debugPrint('Boot optimistic UI: ${sw.elapsedMilliseconds}ms');
        }
        if (!mounted) return;
        setState(() => _bootReady = true);
        FlutterNativeSplash.remove();
        unawaited(_legacyFirstBoot(sw));
      }
    } catch (e, st) {
      debugPrint('Boot init error: $e\n$st');
      if (!mounted) return;
      setState(() => _bootReady = true);
      FlutterNativeSplash.remove();
      unawaited(_finishFullBoot());
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(AppNavigator.consumePending());
    });
  }

  /// BootStore yokken — SharedPreferences bir kez yüklenir, sonra boot dosyası yazılır.
  Future<void> _legacyFirstBoot(Stopwatch sw) async {
    try {
      await Future.wait([
        ThemePreferenceService.instance.initialize(),
        KpssPreferenceService.instance.initialize(),
      ]);
      await BootStore.syncFrom(
        hasChosenExam: KpssPreferenceService.instance.hasChosenExam,
        themePreference: ThemePreferenceService.instance.preference.name,
        examTrackId: KpssPreferenceService.instance.examTrackId,
      );
      if (kDebugMode) {
        debugPrint('Boot legacy-path done: ${sw.elapsedMilliseconds}ms');
      }
    } catch (e, st) {
      debugPrint('Boot legacy error: $e\n$st');
    }
    if (!mounted) return;
    setState(() => _bootReady = true);
    FlutterNativeSplash.remove();
    unawaited(_finishFullBoot());
  }

  Future<void> _finishFullBoot() async {
    unawaited(_finishAuthBoot());
    unawaited(_initializeHeavyInBackground());
    unawaited(_initFirebaseInBackground());
    if (!KpssPreferenceService.instance.isInitialized ||
        !ThemePreferenceService.instance.isInitialized) {
      try {
        await Future.wait([
          if (!ThemePreferenceService.instance.isInitialized)
            ThemePreferenceService.instance.initialize(),
          if (!KpssPreferenceService.instance.isInitialized)
            KpssPreferenceService.instance.initialize(),
        ]);
        await BootStore.syncFrom(
          hasChosenExam: KpssPreferenceService.instance.hasChosenExam,
          themePreference: ThemePreferenceService.instance.preference.name,
          examTrackId: KpssPreferenceService.instance.examTrackId,
        );
        if (mounted) setState(() {});
      } catch (e, st) {
        debugPrint('Boot prefs sync error: $e\n$st');
      }
    }
  }

  Future<void> _finishAuthBoot() async {
    final sw = Stopwatch()..start();
    try {
      await AuthService.instance.initialize();
      final user = AuthService.instance.user;
      if (user != null) {
        DatabaseService.instance.setCurrentUser(user);
      }
      if (kDebugMode) {
        debugPrint('Boot auth-ready: ${sw.elapsedMilliseconds}ms');
      }
    } catch (e, st) {
      debugPrint('Auth init error: $e\n$st');
    }
    if (mounted) setState(() {});
  }

  Future<void> _initFirebaseInBackground() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e, st) {
      debugPrint('Firebase init error: $e\n$st');
    }
  }

  Future<void> _initializeHeavyInBackground() async {
    try {
      await Future.wait([
        NotificationPreferenceService.instance.initialize(),
        ExamCatalogService.instance.initialize(),
      ]);
      await initializeDatabaseFactory();
      await LocalDatabase.instance.initialize();
      await DailyMiniExamService.instance.initialize(
        kpssType: KpssPreferenceService.instance.kpssType,
      );
      // Hafif local servisler paralel
      await Future.wait([
        PracticeExamService.instance.initialize(),
        NotesService.instance.initialize(),
        FavoritesService.instance.initialize(),
        AdFreeCampaignService.instance.initialize(),
        SmartReviewService.instance.initialize(),
        OfflinePackService.instance.initialize(),
        AnnouncementService.instance.initialize(),
        UserMessageService.instance.initialize(),
      ]);
      await UserSavingsInsightService.instance.initialize();
      // Content bank _boot() içinde erken başlatıldı
      await LastStudySessionService.instance.initialize();
    } catch (e, st) {
      debugPrint('Local service init error: $e\n$st');
    }

    // Ağ / SDK — ana sayfadan sonra, birbirini bekletmeden
    unawaited(_safeInit(() => AdManager.instance.initialize(), 'ads'));
    unawaited(
        _safeInit(() => PlayBillingService.instance.initialize(), 'billing'));
    unawaited(
        _safeInit(() => NotificationService.instance.initialize(), 'notif'));
    unawaited(
        _safeInit(() => PushNotificationService.instance.initialize(), 'push'));
    unawaited(_syncContentInBackground());
  }

  Future<void> _safeInit(Future<void> Function() fn, String tag) async {
    try {
      await fn();
    } catch (e, st) {
      debugPrint('$tag init error: $e\n$st');
    }
  }

  Future<void> _syncContentInBackground() async {
    try {
      final ok = await ContentSyncService.instance.syncCatalog(force: true);
      debugPrint(
        ok
            ? 'Content sync on launch OK v${ContentBankService.instance.packVersion}'
            : 'Content sync on launch FAILED (API: ${ApiConfig.baseUrl})',
      );
    } catch (e, st) {
      debugPrint('Content sync on launch error: $e\n$st');
    }
  }

  Future<void> _checkNetworkSecurity() async {
    final unsafe = await _networkSecurity.hasUnsafeConnection();
    if (!mounted) return;
    setState(() {
      _isConnectionBlocked = unsafe;
      _securityChecked = true;
    });
    if (unsafe) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigatorContext = AppNavigator.key.currentContext;
        if (mounted && navigatorContext != null) {
          showSecurityWarningModal(navigatorContext);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;

    Widget home;
    if (_isConnectionBlocked && _securityChecked) {
      home = const _BlockedHomeScreen();
    } else if (!_bootReady) {
      home = const BootSplashScreen();
    } else if (!KpssPreferenceService.instance.hasChosenExam) {
      home = const AppEntry();
    } else if (!auth.isSignedIn) {
      home = _SessionRetryScreen(
        message: auth.lastError,
        onRetry: () async {
          await auth.ensureAnonymousSession();
          if (mounted) setState(() {});
        },
      );
    } else {
      home = const AppEntry();
    }

    return ListenableBuilder(
      listenable: ThemePreferenceService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: BrandConstants.appName,
          navigatorKey: AppNavigator.key,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemePreferenceService.instance.themeMode,
          builder: (context, child) {
            if (!kIsWeb || child == null) {
              return child ?? const SizedBox.shrink();
            }
            final dark = Theme.of(context).brightness == Brightness.dark;
            return ColoredBox(
              color: dark ? const Color(0xFF0A101C) : const Color(0xFFD8DEE8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Material(
                    elevation: 12,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    child: child,
                  ),
                ),
              ),
            );
          },
          home: home,
        );
      },
    );
  }
}

class _SessionRetryScreen extends StatelessWidget {
  const _SessionRetryScreen({
    required this.onRetry,
    this.message,
  });

  final Future<void> Function() onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: AppTheme.champagne,
              ),
              const SizedBox(height: 20),
              Text(
                'Oturum başlatılamadı',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontFamily: 'serif',
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                message ?? 'İnternet bağlantını kontrol edip tekrar dene.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => onRetry(),
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedHomeScreen extends StatelessWidget {
  const _BlockedHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 56,
                color: AppTheme.champagne,
              ),
              const SizedBox(height: 24),
              Text(
                'Uygulama Kilitli',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Güvenli bağlantı sağlanana kadar ${BrandConstants.appName} kullanılamaz.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
