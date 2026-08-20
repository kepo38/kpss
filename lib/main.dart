import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:intl/date_symbol_data_local.dart';

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
import 'services/app_config_service.dart';
import 'services/auth_service.dart';
import 'services/content_bank_service.dart';
import 'services/content_sync_service.dart';
import 'services/database_bootstrap.dart';
import 'services/database_service.dart';
import 'services/favorites_service.dart';
import 'services/summary_card_progress_service.dart';
import 'services/gamification_service.dart';
import 'services/last_study_session_service.dart';
import 'services/local_database.dart';
import 'services/notes_service.dart';
import 'services/question_note_service.dart';
import 'services/exam_catalog_service.dart';
import 'services/kpss_preference_service.dart';
import 'services/theme_preference_service.dart';
import 'services/user_savings_insight_service.dart';
import 'services/daily_mini_exam_service.dart';
import 'services/network_security_gate.dart';
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
  bool _vpnModalShown = false;

  /// Auth hazır → hemen ana sayfa (ağır servisler arka planda).
  bool _bootReady = false;
  bool _showLaunchSplash = true;
  bool _minSplashDone = false;
  bool _bootDataReady = false;
  bool _showAssignmentSplash = false;
  bool? _routedSignedIn;
  String? _routedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService.instance.addListener(_onAuthChanged);
    PlayBillingService.instance.premiumNotifier
        .addListener(_liftVpnLockIfPremium);
    // Varsayılan tercihler — ilk karede UI çizebilsin.
    final defaults = BootSnapshot.defaults();
    ThemePreferenceService.instance.applyBootSnapshot(defaults);
    KpssPreferenceService.instance.applyBootSnapshot(defaults);
    unawaited(OrientationPolicy.apply());
    unawaited(_boot());
    unawaited(_minLaunchSplash());
    unawaited(_checkNetworkSecurity());
  }

  Future<void> _minLaunchSplash() async {
    await Future<void>.delayed(kAssignmentSplashDuration);
    _minSplashDone = true;
    _tryDismissLaunchSplash();
  }

  void _tryDismissLaunchSplash() {
    if (!mounted) return;
    final needsExamChoice = !KpssPreferenceService.instance.hasChosenExam;
    if (needsExamChoice) {
      setState(() => _showLaunchSplash = false);
      FlutterNativeSplash.remove();
      return;
    }
    if (!_minSplashDone || !_bootDataReady) return;
    setState(() => _showLaunchSplash = false);
    FlutterNativeSplash.remove();
  }

  void _beginAssignmentSplash() {
    setState(() => _showAssignmentSplash = true);
  }

  void _finishAssignmentSplash() {
    if (!mounted) return;
    setState(() => _showAssignmentSplash = false);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    PlayBillingService.instance.premiumNotifier
        .removeListener(_liftVpnLockIfPremium);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onAuthChanged() {
    _liftVpnLockIfPremium();
    if (!mounted || !_bootReady) return;
    final auth = AuthService.instance;
    final user = auth.user;
    if (user != null) {
      DatabaseService.instance.setCurrentUser(user);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        unawaited(AppNavigator.consumePending());
      });
    }
    // İsim/premium gibi profil güncellemelerinde MaterialApp'i yeniden
    // kurma — kapanan dialog overlay'i _dependents.isEmpty hatası verir.
    final signedIn = auth.isSignedIn;
    final userId = user?.id;
    if (signedIn == _routedSignedIn && userId == _routedUserId) return;
    _routedSignedIn = signedIn;
    _routedUserId = userId;
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
    unawaited(_finishAuthBoot());

    try {
      await _loadBootPreferences();
      if (kDebugMode) {
        debugPrint(
          'Boot prefs-ready: ${sw.elapsedMilliseconds}ms '
          'chosen=${KpssPreferenceService.instance.hasChosenExam}',
        );
      }
    } catch (e, st) {
      debugPrint('Boot init error: $e\n$st');
    }

    if (!mounted) return;
    final needsExamChoice = !KpssPreferenceService.instance.hasChosenExam;
    setState(() {
      _bootReady = true;
      _bootDataReady = true;
      if (needsExamChoice) _showLaunchSplash = false;
    });
    if (needsExamChoice) {
      FlutterNativeSplash.remove();
    } else {
      _tryDismissLaunchSplash();
    }

    unawaited(_finishFullBoot());

    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(AppNavigator.consumePending());
    });
  }

  Future<void> _loadBootPreferences() async {
    if (await BootStore.exists()) {
      final snap = await BootStore.load();
      ThemePreferenceService.instance.applyBootSnapshot(snap);
      KpssPreferenceService.instance.applyBootSnapshot(snap);
    }
    await Future.wait([
      ThemePreferenceService.instance.initialize(),
      KpssPreferenceService.instance.initialize(),
    ]);
    await BootStore.syncFrom(
      hasChosenExam: KpssPreferenceService.instance.hasChosenExam,
      themePreference: ThemePreferenceService.instance.preference.name,
      examTrackId: KpssPreferenceService.instance.examTrackId,
    );
    if (mounted) setState(() {});
  }

  Future<void> _finishFullBoot() async {
    await initializeDateFormatting('tr', null);
    unawaited(_initializeHeavyInBackground());
    unawaited(_initFirebaseInBackground());
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
        QuestionNoteService.instance.initialize(),
        FavoritesService.instance.initialize(),
        SummaryCardProgressService.instance.initialize(),
        AdFreeCampaignService.instance.initialize(),
        SmartReviewService.instance.initialize(),
        OfflinePackService.instance.initialize(),
        AnnouncementService.instance.initialize(),
        AppConfigService.instance.initialize(),
        UserMessageService.instance.initialize(),
      ]);
      await UserSavingsInsightService.instance.initialize();
      // Content bank _boot() içinde erken başlatıldı
      await LastStudySessionService.instance.initialize();
      await GamificationService.instance.initialize();
      await GamificationService.instance.onPracticeExamAdded(
        totalExams: PracticeExamService.instance.allExams.length,
      );
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
    final blocked = await NetworkSecurityGate.shouldBlock(_networkSecurity);
    if (!mounted) return;
    setState(() {
      _isConnectionBlocked = blocked;
      _securityChecked = true;
    });
    if (!blocked) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isConnectionBlocked || _vpnModalShown) return;
      final navigatorContext = AppNavigator.key.currentContext;
      if (navigatorContext == null) return;
      _vpnModalShown = true;
      showSecurityWarningModal(navigatorContext).whenComplete(() {
        _vpnModalShown = false;
      });
    });
  }

  void _liftVpnLockIfPremium() {
    if (!NetworkSecurityGate.isPremiumExempt) return;
    if (!_isConnectionBlocked && !_vpnModalShown) return;
    if (mounted) {
      setState(() => _isConnectionBlocked = false);
    } else {
      _isConnectionBlocked = false;
    }
    if (!_vpnModalShown) return;
    final nav = AppNavigator.key.currentState;
    if (nav != null && nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemePreferenceService.instance,
        AuthService.instance,
        KpssPreferenceService.instance,
      ]),
      builder: (context, _) {
        final auth = AuthService.instance;
        final Widget home;
        if (_isConnectionBlocked && _securityChecked) {
          home = const _BlockedHomeScreen();
        } else if (!_bootReady) {
          home = const SizedBox.shrink();
        } else if (_showLaunchSplash) {
          home = const BootSplashScreen();
        } else if (_showAssignmentSplash) {
          home = BootSplashScreen(onComplete: _finishAssignmentSplash);
        } else if (!KpssPreferenceService.instance.hasChosenExam) {
          home = AppEntry(onExamChosen: _beginAssignmentSplash);
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
