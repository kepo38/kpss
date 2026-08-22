import 'package:flutter/material.dart';

import '../models/announcement_model.dart';
import '../screens/announcements_screen.dart';
import '../screens/premium/premium_paywall_screen.dart';
import '../screens/tg_exam/exam_welcome_screen.dart';
import '../screens/tg_exam/tg_exam_instant_summary_screen.dart';
import '../screens/tg_exam/tg_exam_result_screen.dart';
import '../services/announcement_service.dart';
import '../services/tg_exam_service.dart';
import '../services/user_message_service.dart';
import '../screens/user_messages_screen.dart';

/// Bildirim tıklaması → duyuru / mesaj detayı.
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static int? _pendingAnnouncementId;
  static String? _pendingAnnouncementTitle;
  static String? _pendingAnnouncementBody;
  static String? _pendingAnnouncementImage;
  static int? _pendingMessageId;
  static int? _pendingTgExamId;
  static int? _pendingTgExamResultsId;
  static bool _pendingPremiumPaywall = false;

  static NavigatorState? get _nav => key.currentState;

  /// FCM / local payload — hemen aç veya oturum hazır olunca aç.
  static Future<void> handlePushData(Map<String, dynamic> data) async {
    final type = '${data['type'] ?? ''}';
    if (type == 'content_update') return;
    if (type == 'daily_mini_exam' || type == 'daily_missions') return;

    if (type == 'tg_exam_results') {
      final examId = int.tryParse('${data['exam_id']}');
      if (examId == null) return;
      if (_nav != null) {
        await openTgExamResults(examId);
      } else {
        _pendingTgExamResultsId = examId;
      }
      return;
    }

    if (type == 'tg_exam') {
      final examId = int.tryParse('${data['exam_id']}');
      if (examId == null) return;
      if (_nav != null) {
        await openTgExam(examId);
      } else {
        _pendingTgExamId = examId;
      }
      return;
    }

    if (type == 'premium') {
      if (_nav != null) {
        await openPremiumPaywall();
      } else {
        _pendingPremiumPaywall = true;
      }
      return;
    }

    if (type == 'user_message' || data.containsKey('message_id')) {
      final id = int.tryParse('${data['message_id']}');
      if (id == null) return;
      await UserMessageService.instance.refresh();
      await UserMessageService.instance.markRead(id);
      if (_nav != null) {
        await openUserMessage(id);
      } else {
        _pendingMessageId = id;
      }
      return;
    }

    // Duyuru (type=announcement veya announcement_id)
    final id = int.tryParse('${data['announcement_id']}');
    if (id == null && type != 'announcement') return;

    await AnnouncementService.instance.refresh();
    if (id != null) {
      await AnnouncementService.instance.markRead(id);
    }

    final title = (data['title'] as String?)?.trim();
    final body = (data['body'] as String?)?.trim();
    final image = (data['image_url'] as String?)?.trim();

    if (_nav != null && id != null) {
      await openAnnouncement(
        id,
        fallbackTitle: title,
        fallbackBody: body,
        fallbackImageUrl: image,
      );
    } else if (id != null) {
      _pendingAnnouncementId = id;
      _pendingAnnouncementTitle = title;
      _pendingAnnouncementBody = body;
      _pendingAnnouncementImage = image;
    } else if (_nav != null) {
      await openAnnouncementsList();
    }
  }

  /// Auth + MaterialApp hazır olduktan sonra bekleyen linki tüket.
  static Future<void> consumePending() async {
    final annId = _pendingAnnouncementId;
    final msgId = _pendingMessageId;
    final tgExamId = _pendingTgExamId;
    final tgResultsId = _pendingTgExamResultsId;
    final premium = _pendingPremiumPaywall;
    if (annId == null &&
        msgId == null &&
        tgExamId == null &&
        tgResultsId == null &&
        !premium) {
      return;
    }

    // Navigator mount olana kadar kısa bekle
    for (var i = 0; i < 20 && _nav == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (_nav == null) return;

    _pendingAnnouncementId = null;
    _pendingMessageId = null;
    _pendingTgExamId = null;
    _pendingTgExamResultsId = null;
    _pendingPremiumPaywall = false;

    if (premium) {
      await openPremiumPaywall();
      return;
    }
    if (tgResultsId != null) {
      await openTgExamResults(tgResultsId);
      return;
    }
    if (tgExamId != null) {
      await openTgExam(tgExamId);
      return;
    }
    if (msgId != null) {
      await openUserMessage(msgId);
      return;
    }
    if (annId != null) {
      await openAnnouncement(
        annId,
        fallbackTitle: _pendingAnnouncementTitle,
        fallbackBody: _pendingAnnouncementBody,
        fallbackImageUrl: _pendingAnnouncementImage,
      );
      _pendingAnnouncementTitle = null;
      _pendingAnnouncementBody = null;
      _pendingAnnouncementImage = null;
    }
  }

  static Future<void> openPremiumPaywall() async {
    final nav = _nav;
    if (nav == null) return;
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const PremiumPaywallScreen(),
      ),
    );
  }

  static Future<void> openAnnouncementsList() async {
    final nav = _nav;
    if (nav == null) return;
    await AnnouncementService.instance.refresh();
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const AnnouncementsScreen(),
      ),
    );
  }

  static Future<void> openAnnouncement(
    int id, {
    String? fallbackTitle,
    String? fallbackBody,
    String? fallbackImageUrl,
  }) async {
    final nav = _nav;
    if (nav == null) return;

    await AnnouncementService.instance.refresh();
    var item = AnnouncementService.instance.byId(id);
    item ??= AnnouncementModel(
      id: id,
      title: (fallbackTitle ?? '').trim().isEmpty
          ? 'Duyuru'
          : fallbackTitle!.trim(),
      body: fallbackBody ?? '',
      imageUrl: (fallbackImageUrl == null || fallbackImageUrl.trim().isEmpty)
          ? null
          : fallbackImageUrl.trim(),
    );

    await AnnouncementService.instance.markRead(id);
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => AnnouncementDetailScreen(announcement: item!),
      ),
    );
  }

  static Future<void> openUserMessage(int id) async {
    final nav = _nav;
    if (nav == null) return;

    await UserMessageService.instance.refresh();
    final item = UserMessageService.instance.byId(id);
    if (item == null) {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const UserMessagesScreen(),
        ),
      );
      return;
    }
    await UserMessageService.instance.markRead(id);
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => UserMessageDetailScreen(message: item),
      ),
    );
  }

  static Future<void> openTgExam(int examId) async {
    final nav = _nav;
    if (nav == null) return;
    await TgExamService.instance.fetchDetail(examId);
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ExamWelcomeScreen(examId: examId),
      ),
    );
  }

  /// Sonuç bildirimi deeplink — doğrudan sonuç / sıralama ekranı.
  static Future<void> openTgExamResults(int examId) async {
    final nav = _nav;
    if (nav == null) return;

    final exam = await TgExamService.instance.fetchDetail(examId);
    if (exam == null) {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => ExamWelcomeScreen(examId: examId),
        ),
      );
      return;
    }

    if (exam.canAccessDetailedAnalysis) {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => TgExamResultScreen(exam: exam),
        ),
      );
      return;
    }

    if (exam.hasSubmittedAttempt) {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => TgExamInstantSummaryScreen(exam: exam),
        ),
      );
      return;
    }

    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ExamWelcomeScreen(examId: examId),
      ),
    );
  }
}
