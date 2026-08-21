import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../constants/brand_constants.dart';
import '../navigation/app_navigator.dart';
import '../utils/daily_mission_copy.dart';
import 'content_bank_service.dart';
import 'kpss_preference_service.dart';
import 'notification_preference_service.dart';
import 'practice_exam_service.dart';

/// Bir sonraki günlük tetik (yerel saat). Saat geçmişse yarına kayar.
DateTime nextDailyFire(
  DateTime from, {
  required int hour,
  int minute = 0,
}) {
  final scheduled = DateTime(from.year, from.month, from.day, hour, minute);
  if (scheduled.isAfter(from)) return scheduled;
  return scheduled.add(const Duration(days: 1));
}

/// Haftalık özet, sabah motivasyon ve gece FOMO hatırlatmaları.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  bool _initialized = false;
  bool _listeningProgress = false;

  static const int weeklySummaryId = 1000;
  static const int premiumSavingsNotificationId = 1001;
  static const int dailyMiniExamId = 1002;
  static const int morningMotivationId = 1003;
  static const int eveningFomoId = 1004;
  static const int examReminderId = 1005;
  static const _eveningSentKey = 'evening_fomo_sent_date_v1';
  static const _examReminderKey = 'exam_sunday_reminder_v1';

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final payload = launch!.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        _handlePayload(payload);
      }
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
    if (!_listeningProgress) {
      ContentBankService.instance.addListener(_onProgressChanged);
      _listeningProgress = true;
    }
    await ensureScheduled();
  }

  void _onProgressChanged() {
    scheduleEveningFomo();
  }

  /// Tercih değişince zamanlamayı uygular.
  Future<void> applyPreferences() async {
    await ensureScheduled();
  }

  /// Açılış ve öne gelince zamanlanmış bildirimleri yeniler.
  Future<void> ensureScheduled() async {
    if (!_initialized) return;
    await scheduleWeeklySummary();
    await scheduleMorningMotivation();
    await scheduleEveningFomo();
    await scheduleExamReminderIfEnabled();
  }

  Future<bool> isExamReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_examReminderKey) ?? false;
  }

  /// Pazar 10:00 deneme hatırlatıcısını aç/kapa.
  Future<bool> setExamReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_examReminderKey, enabled);
    if (enabled) {
      await scheduleExamReminderIfEnabled();
    } else {
      await _plugin.cancel(examReminderId);
    }
    return enabled;
  }

  Future<void> scheduleExamReminderIfEnabled() async {
    if (!_initialized) return;
    await _plugin.cancel(examReminderId);
    if (!await isExamReminderEnabled()) return;

    await _plugin.zonedSchedule(
      examReminderId,
      '${BrandConstants.appName} — Deneme zamanı',
      'Pazar deneme hatırlatması: bugün bir deneme çöz, netlerini güncelle.',
      _nextWeeklyAt(weekday: DateTime.sunday, hour: 10),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'exam_reminder',
          'Deneme Hatırlatıcısı',
          channelDescription: 'Her Pazar 10:00 deneme çözme hatırlatması',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  bool _pref(NotificationKind kind) =>
      NotificationPreferenceService.instance.isEnabled(kind);

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _handlePayload(payload);
  }

  void _handlePayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        AppNavigator.handlePushData(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      debugPrint('Bildirim payload: $e');
    }
  }

  Future<void> scheduleWeeklySummary() async {
    if (!_initialized) return;
    await _plugin.cancel(weeklySummaryId);
    if (!_pref(NotificationKind.weeklySummary)) return;

    await _plugin.zonedSchedule(
      weeklySummaryId,
      '${BrandConstants.appName} — Haftalık Özet',
      _buildWeeklySummaryBody(),
      _nextWeeklyAt(weekday: DateTime.sunday, hour: 15),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_summary',
          'Haftalık Performans Özeti',
          channelDescription:
              'Haftalık deneme net gelişiminiz ve yanlış konu hatırlatmaları',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  String _buildWeeklySummaryBody() {
    final summary = PracticeExamService.instance.weeklySummary;
    final bank = ContentBankService.instance;
    final wrongCount = bank.wrongQuestionCount;
    final topics = bank.wrongTopicsSummary(limit: 3);
    final degisim = summary.netDegisim >= 0 ? '+' : '';

    final buffer = StringBuffer(
      'Bu hafta ${summary.denemeSayisi} deneme, '
      'ort. ${summary.ortalamaNet.toStringAsFixed(1)} net '
      '($degisim${summary.netDegisim.toStringAsFixed(1)}). ',
    );

    if (wrongCount == 0) {
      buffer.write('Yanlış defterin boş.');
    } else {
      buffer.write('$wrongCount yanlış soru');
      if (topics.isNotEmpty) {
        final topicText = topics
            .map((t) => '${t.$1} (${t.$2})')
            .join(', ');
        buffer.write(' — tekrar: $topicText');
      }
      buffer.write('.');
    }

    return buffer.toString();
  }

  Future<void> refreshWeeklySummaryContent() async {
    if (!_initialized) return;
    if (!_pref(NotificationKind.weeklySummary)) return;
    await _plugin.show(
      weeklySummaryId,
      '${BrandConstants.appName} — Haftalık Özet',
      _buildWeeklySummaryBody(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_summary',
          'Haftalık Performans Özeti',
          channelDescription: 'Haftalık deneme performans raporu',
        ),
      ),
    );
  }

  /// 20 test kilometre taşı — tıklanınca paywall açılır.
  Future<void> showPremiumSavingsNotification({
    required int savingsTl,
  }) async {
    if (!_initialized) return;

    final payload = jsonEncode({
      'type': 'premium',
      'savings_tl': savingsTl,
    });

    await _plugin.show(
      premiumSavingsNotificationId,
      '${BrandConstants.appName} — Kazancın',
      'Bu ay şimdiye kadar reklam izleyerek '
          '$savingsTl liralık testi ücretsiz çözdün! '
          'Akıllı PDF ile başarını taçlandır.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'savings_milestones',
          'Kazanç ve Premium',
          channelDescription:
              'Ücretsiz test kazancı ve premium fırsat bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }

  /// Her gün 09:00 — günlük ücretsiz test / bar motivasyonu.
  Future<void> scheduleMorningMotivation() async {
    if (!_initialized) return;

    await _plugin.cancel(dailyMiniExamId);
    await _plugin.cancel(morningMotivationId);
    if (!_pref(NotificationKind.morningMotivation)) return;

    final payload = jsonEncode({'type': 'daily_missions'});

    await _plugin.zonedSchedule(
      morningMotivationId,
      DailyMissionCopy.morningTitle,
      DailyMissionCopy.morningBody,
      _nextDailyAt(hour: DailyMissionCopy.morningHour),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_missions',
          'Günlük görevler',
          channelDescription: 'Sabah motivasyon ve gece görev hatırlatmaları',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  /// 21:00 FOMO — yalnızca 4 bar dolu, 1 ders kalınca.
  Future<void> scheduleEveningFomo() async {
    if (!_initialized) return;

    await _plugin.cancel(eveningFomoId);
    if (!_pref(NotificationKind.eveningFomo)) return;

    final progress = ContentBankService.instance.dailyMissionProgress(
      KpssPreferenceService.instance.kpssType,
    );
    if (!progress.isFourDoneOneLeft) return;

    final remaining = progress.remainingName;
    if (remaining == null) return;

    final payload = jsonEncode({'type': 'daily_missions'});
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_missions',
        'Günlük görevler',
        channelDescription: 'Sabah motivasyon ve gece görev hatırlatmaları',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final body = DailyMissionCopy.eveningBody(remaining);
    final now = tz.TZDateTime.now(tz.local);

    if (now.hour >= DailyMissionCopy.eveningHour) {
      await _showEveningFomoOnce(body, details, payload);
      return;
    }

    await _plugin.zonedSchedule(
      eveningFomoId,
      DailyMissionCopy.eveningTitle,
      body,
      _nextDailyAt(hour: DailyMissionCopy.eveningHour),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> _showEveningFomoOnce(
    String body,
    NotificationDetails details,
    String payload,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _isoDay(DateTime.now());
    if (prefs.getString(_eveningSentKey) == today) return;
    await prefs.setString(_eveningSentKey, today);
    await _plugin.show(
      eveningFomoId,
      DailyMissionCopy.eveningTitle,
      body,
      details,
      payload: payload,
    );
  }

  String _isoDay(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  tz.TZDateTime _nextDailyAt({required int hour, int minute = 0}) {
    final now = tz.TZDateTime.now(tz.local);
    final next = nextDailyFire(now, hour: hour, minute: minute);
    return tz.TZDateTime(
      tz.local,
      next.year,
      next.month,
      next.day,
      next.hour,
      next.minute,
    );
  }

  tz.TZDateTime _nextWeeklyAt({
    required int weekday,
    required int hour,
    int minute = 0,
  }) {
    var scheduled = tz.TZDateTime(
      tz.local,
      tz.TZDateTime.now(tz.local).year,
      tz.TZDateTime.now(tz.local).month,
      tz.TZDateTime.now(tz.local).day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday ||
        scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
