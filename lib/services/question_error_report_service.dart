import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class QuestionErrorReportState {
  final bool reported;
  final String? category;
  final String? status;
  final bool dailyLimitReached;
  final bool canReport;

  const QuestionErrorReportState({
    required this.reported,
    this.category,
    this.status,
    this.dailyLimitReached = false,
    this.canReport = true,
  });

  factory QuestionErrorReportState.fromJson(Map<String, dynamic> json) {
    final reported = json['reported'] == true;
    final dailyLimit = json['dailyLimitReached'] == true;
    final canReport = json.containsKey('canReport')
        ? json['canReport'] == true
        : (!reported && !dailyLimit);
    return QuestionErrorReportState(
      reported: reported,
      category: json['category'] as String?,
      status: json['status'] as String?,
      dailyLimitReached: dailyLimit,
      canReport: canReport,
    );
  }
}

class QuestionErrorReportException implements Exception {
  final String message;
  const QuestionErrorReportException(this.message);

  @override
  String toString() => message;
}

class QuestionErrorReportService {
  QuestionErrorReportService._();
  static final QuestionErrorReportService instance =
      QuestionErrorReportService._();

  final Map<String, QuestionErrorReportState> _cache = {};
  bool? _dailyLimitReached;

  String _cacheKey(String questionId) {
    final userId = AuthService.instance.user?.id ?? 'anonymous';
    return '$userId:$questionId';
  }

  QuestionErrorReportState? cached(String questionId) =>
      _cache[_cacheKey(questionId)];

  bool get dailyLimitReached => _dailyLimitReached == true;

  void clear() {
    _cache.clear();
    _dailyLimitReached = null;
  }

  static bool canReport(String questionId) {
    final id = questionId.trim();
    if (id.isEmpty) return false;
    return !RegExp(r'^q_(tr|mat)_\d+$').hasMatch(id);
  }

  Future<QuestionErrorReportState> load(String questionId) async {
    final auth = AuthService.instance;
    if (!auth.hasBackendSession) {
      throw const QuestionErrorReportException(
        'Bildirmek için giriş yapın.',
      );
    }
    final response = await http
        .get(
          ApiConfig.questionErrorReportUri(questionId),
          headers: auth.authHeaders,
        )
        .timeout(const Duration(seconds: 10));
    return _decode(questionId, response);
  }

  Future<QuestionErrorReportState> submit({
    required String questionId,
    required String category,
    String note = '',
  }) async {
    final auth = AuthService.instance;
    if (!auth.hasBackendSession) {
      throw const QuestionErrorReportException(
        'Bildirmek için giriş yapın.',
      );
    }
    final response = await http
        .post(
          ApiConfig.questionErrorReportUri(questionId),
          headers: {
            ...auth.authHeaders,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'category': category,
            'note': note.trim(),
          }),
        )
        .timeout(const Duration(seconds: 12));
    return _decode(questionId, response);
  }

  QuestionErrorReportState _decode(String questionId, http.Response response) {
    if (response.statusCode == 429) {
      _dailyLimitReached = true;
      var message = 'Günde yalnızca 1 hata bildirimi yapabilirsiniz.';
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map && body['detail'] != null) {
          message = body['detail'].toString();
        }
      } catch (_) {}
      throw QuestionErrorReportException(message);
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      var message = 'Bildirim gönderilemedi.';
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map && body['detail'] != null) {
          message = body['detail'].toString();
        }
      } catch (_) {}
      throw QuestionErrorReportException(message);
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map) {
      throw const QuestionErrorReportException('Geçersiz sunucu yanıtı.');
    }
    final state = QuestionErrorReportState.fromJson(
      Map<String, dynamic>.from(body),
    );
    _cache[_cacheKey(questionId)] = state;
    _dailyLimitReached = state.dailyLimitReached;
    return state;
  }

  static const reportCategories = [
    ('wrong_answer', 'Cevap anahtarı yanlış'),
    ('outdated', 'Soru güncel değil'),
    ('typo', 'Yazım / ifade hatası'),
    ('missing_content', 'Eksik görsel / şekil'),
    ('other', 'Diğer'),
  ];
}
