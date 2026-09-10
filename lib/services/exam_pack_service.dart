import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/exam_pack_model.dart';
import 'auth_service.dart';
import 'play_billing_service.dart';
import 'question_fetch_service.dart';

/// Deneme paketi kataloğu — API + yerel önbellek.
class ExamPackService extends ChangeNotifier {
  ExamPackService._();
  static final ExamPackService instance = ExamPackService._();

  static const _cacheKey = 'exam_packs_cache_v1';

  List<ExamPackModel> _packs = [];
  bool _loading = false;
  String? _error;
  String? _cachedExamTypeId;
  String? _pendingExamTypeId;

  List<ExamPackModel> get packs => List.unmodifiable(_packs);
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> refresh({required String examTypeId}) async {
    if (_loading) {
      _pendingExamTypeId = examTypeId;
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final uri = ApiConfig.examPacksUri(examTypeId: examTypeId);
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final body =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final raw = body['packs'] as List<dynamic>? ?? const [];
        _packs = raw
            .map(
              (e) => ExamPackModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
        _cachedExamTypeId = examTypeId;
        _error = null;
        await _persistCache(examTypeId);
        await PlayBillingService.instance.syncPackProductIds(
          _packs.map((p) => p.playProductId).where((id) => id.isNotEmpty),
        );
      } else {
        _error = 'Paket listesi alınamadı (${response.statusCode}).';
        await _loadCache(examTypeId);
      }
    } catch (e) {
      debugPrint('ExamPackService.refresh: $e');
      _error = 'Deneme paketleri yüklenemedi.';
      await _loadCache(examTypeId);
    } finally {
      _loading = false;
      notifyListeners();
      final pending = _pendingExamTypeId;
      if (pending != null && pending != examTypeId) {
        _pendingExamTypeId = null;
        unawaited(refresh(examTypeId: pending));
      } else {
        _pendingExamTypeId = null;
      }
    }
  }

  Future<ExamPackModel?> fetchDetail(String packId) async {
    try {
      final response = await http
          .get(
            ApiConfig.examPackDetailUri(packId),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return ExamPackModel.fromJson(body);
    } catch (e) {
      debugPrint('ExamPackService.fetchDetail: $e');
      return null;
    }
  }

  Future<QuestionFetchResult> fetchExamQuestions({
    required String packId,
    required int examIndex,
  }) async {
    try {
      final response = await http
          .get(
            ApiConfig.examPackExamQuestionsUri(packId, examIndex),
            headers: AuthService.instance.authHeaders,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        return const QuestionFetchResult(
          questions: [],
          errorMessage:
              'Deneme paketleri için Google ile giriş yapmalısınız.',
        );
      }
      if (response.statusCode == 409) {
        final detail = _errorDetail(response.body);
        return QuestionFetchResult(
          questions: const [],
          errorMessage: detail ??
              'Bu deneme için yeterli yeni soru bulunamadı.',
        );
      }
      if (response.statusCode != 200) {
        return QuestionFetchResult(
          questions: const [],
          errorMessage: 'Deneme soruları alınamadı (${response.statusCode}).',
        );
      }
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final questions =
          QuestionFetchService.instance.parseQuestionsList(body['questions']);
      return QuestionFetchResult(questions: questions);
    } catch (e) {
      debugPrint('ExamPackService.fetchExamQuestions: $e');
      return const QuestionFetchResult(
        questions: [],
        errorMessage: 'Deneme soruları yüklenemedi.',
      );
    }
  }

  bool isPackOwned(ExamPackModel pack) {
    final sku = pack.playProductId.trim();
    if (sku.isEmpty) return false;
    return PlayBillingService.instance.ownsPackProduct(sku);
  }

  String displayPrice(ExamPackModel pack) {
    final store = PlayBillingService.instance.priceForPackProduct(
      pack.playProductId,
    );
    if (store != null && store.isNotEmpty) return store;
    if (pack.priceDisplay.trim().isNotEmpty) return pack.priceDisplay.trim();
    return 'Satın al';
  }

  Future<void> _persistCache(String examTypeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode({
        'examTypeId': examTypeId,
        'packs': _packs.map(_packToJson).toList(),
      }),
    );
  }

  Future<void> _loadCache(String examTypeId) async {
    if (_packs.isNotEmpty && _cachedExamTypeId == examTypeId) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      final body = jsonDecode(raw) as Map<String, dynamic>;
      if (body['examTypeId'] != examTypeId) return;
      final list = body['packs'] as List<dynamic>? ?? const [];
      _packs = list
          .map(
            (e) => ExamPackModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
      _cachedExamTypeId = examTypeId;
    } catch (_) {}
  }

  Map<String, dynamic> _packToJson(ExamPackModel pack) => {
        'id': pack.id,
        'examTypeId': pack.examTypeId,
        'packKind': pack.packKind,
        'subjectId': pack.subjectId,
        'subjectName': pack.subjectName,
        'title': pack.title,
        'description': pack.description,
        'examCount': pack.examCount,
        'timeLimitMinutes': pack.timeLimitMinutes,
        'priceDisplay': pack.priceDisplay,
        'playProductId': pack.playProductId,
        'questionsPerExam': pack.questionsPerExam,
      };

  String? _errorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {}
    return null;
  }
}
