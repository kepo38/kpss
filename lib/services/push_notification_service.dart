import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../constants/brand_constants.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config/api_config.dart';
import '../navigation/app_navigator.dart';
import 'auth_service.dart';
import 'content_sync_service.dart';
import 'notification_service.dart';
import 'tg_exam_service.dart';

/// FCM push (Play Store bildirimleri) + jeton kaydı + içerik senkron tetikleyici.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const String announcementTopic = 'kpss_duyuru';
  static const String contentTopic = 'kpss_content';
  static const String channelId = 'announcements';
  static const String tgExamsChannelId = 'tg_exams';
  static const Color _tgExamAccent = Color(0xFFC41E3A);

  bool _ready = false;
  Uint8List? _tgExamBannerBytes;

  Future<void> initialize() async {
    if (kIsWeb || _ready) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase init atlandı (google-services.json gerekli): $e');
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    await _ensureAndroidChannels();

    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);

    // Soğuk açılış: uygulama kapalıyken bildirime tıklandı
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      unawaited(_onOpened(initial));
    }

    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerToken(token);
    }
    messaging.onTokenRefresh.listen(_registerToken);

    try {
      await messaging.subscribeToTopic(contentTopic);
    } catch (e) {
      debugPrint('FCM topic $contentTopic: $e');
    }
    await syncAnnouncementSubscription();

    _ready = true;
  }

  /// Duyuru konusu her zaman açıktır.
  Future<void> syncAnnouncementSubscription() async {
    if (kIsWeb) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic(announcementTopic);
    } catch (e) {
      debugPrint('FCM duyuru topic: $e');
    }
  }

  Future<void> _ensureAndroidChannels() async {
    if (!Platform.isAndroid) return;
    final android = NotificationService.instance.plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        'Duyurular',
        description: '${BrandConstants.appName} duyuru ve kampanya bildirimleri',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        tgExamsChannelId,
        'Türkiye Geneli Deneme',
        description: 'TG deneme duyuruları ve sonuç bildirimleri',
        importance: Importance.high,
      ),
    );
  }

  Future<void> _onForeground(RemoteMessage message) async {
    if (_isContentUpdate(message)) {
      unawaited(ContentSyncService.instance.syncCatalog(force: true));
      return;
    }
    if (_isOpenTgExamNotice(message)) return;

    if (_isPremiumTgExamNotice(message)) {
      await _showPremiumTgExamNotice(message);
      return;
    }

    final title =
        message.notification?.title ?? message.data['title'] ?? BrandConstants.appName;
    final body = message.notification?.body ?? message.data['body'] ?? '';
    if (body.isEmpty && message.notification == null) return;

    final payload = jsonEncode(Map<String, dynamic>.from(message.data));
    final imageUrl = message.notification?.android?.imageUrl ??
        message.notification?.apple?.imageUrl ??
        message.data['image_url']?.toString();

    BigPictureStyleInformation? bigPicture;
    if (Platform.isAndroid &&
        imageUrl != null &&
        imageUrl.trim().isNotEmpty) {
      final bytes = await _downloadImageBytes(imageUrl.trim());
      if (bytes != null && bytes.isNotEmpty) {
        final bitmap = ByteArrayAndroidBitmap(bytes);
        bigPicture = BigPictureStyleInformation(
          bitmap,
          contentTitle: title.toString(),
          summaryText: body.toString(),
          hideExpandedLargeIcon: true,
        );
      }
    }

    await NotificationService.instance.plugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Duyurular',
          channelDescription:
              '${BrandConstants.appName} duyuru ve kampanya bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: bigPicture,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> _showPremiumTgExamNotice(RemoteMessage message) async {
    final data = message.data;
    final title = (data['title'] ?? data['exam_title'] ?? 'Türkiye Geneli Deneme')
        .toString();
    final body = (data['body'] ?? message.notification?.body ?? '').toString();
    final headline = (data['headline'] ?? 'Türkiye Geneli Deneme').toString();
    final startsAt = (data['starts_at_label'] ?? '').toString();
    final metrics = (data['metrics_label'] ?? '').toString();
    final cta = (data['cta_hint'] ?? '').toString();

    final expandedLines = <String>[
      headline,
      if (startsAt.isNotEmpty) startsAt,
      if (metrics.isNotEmpty) metrics,
      if (cta.isNotEmpty) cta,
    ].join('\n');

    StyleInformation? styleInformation = BigTextStyleInformation(
      expandedLines,
      contentTitle: title,
      summaryText: body,
      htmlFormatBigText: false,
    );

    if (Platform.isAndroid) {
      final bannerBytes = await _resolveTgExamBannerBytes(data);
      if (bannerBytes != null && bannerBytes.isNotEmpty) {
        styleInformation = BigPictureStyleInformation(
          ByteArrayAndroidBitmap(bannerBytes),
          contentTitle: title,
          summaryText: body.isNotEmpty ? body : headline,
          hideExpandedLargeIcon: true,
        );
      }
    }

    final payload = jsonEncode(Map<String, dynamic>.from(data));
    await NotificationService.instance.plugin.show(
      message.hashCode,
      title,
      body.isNotEmpty ? body : headline,
      NotificationDetails(
        android: AndroidNotificationDetails(
          tgExamsChannelId,
          'Türkiye Geneli Deneme',
          channelDescription: 'TG deneme duyuruları ve sonuç bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
          color: _tgExamAccent,
          styleInformation: styleInformation,
          tag: 'tg_exam_${data['exam_id'] ?? message.hashCode}',
        ),
      ),
      payload: payload,
    );
  }

  Future<Uint8List?> _resolveTgExamBannerBytes(Map<String, dynamic> data) async {
    final imageUrl = data['image_url']?.toString().trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final remote = await _downloadImageBytes(imageUrl);
      if (remote != null && remote.isNotEmpty) return remote;
    }
    _tgExamBannerBytes ??= await _loadAssetBytes(
      'assets/images/tg_exam_push_banner.jpg',
    );
    return _tgExamBannerBytes;
  }

  Future<Uint8List?> _loadAssetBytes(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (e) {
      debugPrint('TG banner asset yüklenemedi: $e');
      return null;
    }
  }

  Future<Uint8List?> _downloadImageBytes(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 8),
          );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return res.bodyBytes;
      }
    } catch (e) {
      debugPrint('Duyuru görseli indirilemedi: $e');
    }
    return null;
  }

  Future<void> _onOpened(RemoteMessage message) async {
    if (_isContentUpdate(message)) {
      unawaited(ContentSyncService.instance.syncCatalog(force: true));
      return;
    }
    await AppNavigator.handlePushData(
      Map<String, dynamic>.from(message.data),
    );
  }

  static bool _isContentUpdate(RemoteMessage message) {
    return message.data['type'] == 'content_update';
  }

  static bool _isPremiumTgExamNotice(RemoteMessage message) {
    final type = message.data['type'];
    return type == 'tg_exam' ||
        type == 'tg_exam_results' ||
        message.data['style'] == 'tg_exam_premium';
  }

  /// Kullanıcı zaten o denemenin ekranındaysa duyuru banner'ı içeriği örtmesin.
  static bool _isOpenTgExamNotice(RemoteMessage message) {
    final type = message.data['type'];
    if (type != 'tg_exam' && type != 'tg_exam_results') return false;
    final examId = int.tryParse('${message.data['exam_id']}');
    if (examId == null) return false;
    return TgExamService.instance.visibleExamId == examId;
  }

  Future<void> _registerToken(String token) async {
    try {
      final package = await PackageInfo.fromPlatform();
      final headers = {
        'Content-Type': 'application/json',
        ...AuthService.instance.authHeaders,
      };
      final res = await http
          .post(
            ApiConfig.deviceTokensUri(),
            headers: headers,
            body: jsonEncode({
              'token': token,
              'platform': Platform.isIOS ? 'ios' : 'android',
              'app_version': package.version,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) {
        debugPrint('Device token kayıt hatası: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('Device token kayıt: $e');
    }
  }
}

/// Arka plan FCM (top-level, Flutter gereksinimi).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  if (message.data['type'] == 'content_update') {
    // Arka planda tam sync app açılınca / periyodik kontrolle tamamlanır.
  }
}
