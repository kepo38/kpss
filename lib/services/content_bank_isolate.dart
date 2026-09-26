import 'dart:convert';

import '../models/content_models.dart';
import '../models/question_model.dart';
import '../widgets/countdown_widget.dart';

/// SharedPreferences'ten okunan ham JSON string'leri (isolate-safe).
class ContentBankRawBundle {
  final String? configs;
  final String? tests;
  final String? attempts;
  final String? solved;
  final String? questions;
  final String? lessons;
  final String? summaryCards;

  const ContentBankRawBundle({
    this.configs,
    this.tests,
    this.attempts,
    this.solved,
    this.questions,
    this.lessons,
    this.summaryCards,
  });
}

/// Isolate'ta decode + fromJson sonucu (main isolate'a taşınır).
class ContentBankParsedBundle {
  final Map<String, TopicTestConfig> configs;
  final List<TopicTestModel> tests;
  final List<TestAttemptModel> attempts;
  final List<String> solvedIds;
  final List<QuestionModel> questions;
  final List<TopicLessonModel> lessons;
  final List<TopicSummaryCardModel> summaryCards;

  const ContentBankParsedBundle({
    required this.configs,
    required this.tests,
    required this.attempts,
    required this.solvedIds,
    required this.questions,
    required this.lessons,
    required this.summaryCards,
  });
}

/// Katalog / yayın paketi meta parse sonucu.
class ContentPackMetadataParsed {
  final List<TopicTestModel> tests;
  final Map<String, TopicTestConfig> configs;
  final List<TopicLessonModel> lessons;
  final List<TopicSummaryCardModel> summaryCards;
  final int? packVersion;

  const ContentPackMetadataParsed({
    required this.tests,
    required this.configs,
    required this.lessons,
    required this.summaryCards,
    this.packVersion,
  });
}

/// Top-level: UI isolate'ı bloklamadan paket parse.
ContentBankParsedBundle parseContentBankBundle(ContentBankRawBundle raw) {
  final configs = <String, TopicTestConfig>{};
  final configsRaw = raw.configs;
  if (configsRaw != null && configsRaw.isNotEmpty) {
    final map = jsonDecode(configsRaw) as Map<String, dynamic>;
    for (final e in map.entries) {
      configs[e.key] = TopicTestConfig.fromJson(
        Map<String, dynamic>.from(e.value as Map),
      );
    }
  }

  final tests = <TopicTestModel>[];
  final testsRaw = raw.tests;
  if (testsRaw != null && testsRaw.isNotEmpty) {
    final list = jsonDecode(testsRaw) as List<dynamic>;
    for (final e in list) {
      tests.add(
        TopicTestModel.fromJson(Map<String, dynamic>.from(e as Map)),
      );
    }
  }

  final attempts = <TestAttemptModel>[];
  final attemptsRaw = raw.attempts;
  if (attemptsRaw != null && attemptsRaw.isNotEmpty) {
    final list = jsonDecode(attemptsRaw) as List<dynamic>;
    for (final e in list) {
      attempts.add(
        TestAttemptModel.fromJson(Map<String, dynamic>.from(e as Map)),
      );
    }
  }

  final solvedIds = <String>[];
  final solvedRaw = raw.solved;
  if (solvedRaw != null && solvedRaw.isNotEmpty) {
    final list = jsonDecode(solvedRaw) as List<dynamic>;
    solvedIds.addAll(list.map((e) => e.toString()));
  }

  final questions = <QuestionModel>[];
  final questionsRaw = raw.questions;
  if (questionsRaw != null && questionsRaw.isNotEmpty) {
    final list = jsonDecode(questionsRaw) as List<dynamic>;
    for (final e in list) {
      questions.add(
        QuestionModel.fromJson(Map<String, dynamic>.from(e as Map)),
      );
    }
  }

  final lessons = <TopicLessonModel>[];
  final lessonsRaw = raw.lessons;
  if (lessonsRaw != null && lessonsRaw.isNotEmpty) {
    final list = jsonDecode(lessonsRaw) as List<dynamic>;
    for (final e in list) {
      lessons.add(
        TopicLessonModel.fromJson(Map<String, dynamic>.from(e as Map)),
      );
    }
  }

  final summaryCards = <TopicSummaryCardModel>[];
  final summaryRaw = raw.summaryCards;
  if (summaryRaw != null && summaryRaw.isNotEmpty) {
    final list = jsonDecode(summaryRaw) as List<dynamic>;
    for (final e in list) {
      summaryCards.add(
        TopicSummaryCardModel.fromJson(Map<String, dynamic>.from(e as Map)),
      );
    }
  }

  return ContentBankParsedBundle(
    configs: configs,
    tests: tests,
    attempts: attempts,
    solvedIds: solvedIds,
    questions: questions,
    lessons: lessons,
    summaryCards: summaryCards,
  );
}

/// syncCatalog / published pack meta — tests/configs/lessons/summaryCards.
ContentPackMetadataParsed parseContentPackMetadata(Map<String, dynamic> pack) {
  final parserTests = <TopicTestModel>[];
  for (final raw in (pack['tests'] as List<dynamic>? ?? const [])) {
    final json = Map<String, dynamic>.from(raw as Map);
    for (final type in KpssType.values) {
      parserTests.add(
        TopicTestModel(
          id: '${json['id']}_${type.name}',
          topicId: json['topicId'] as String,
          kpssType: type,
          title: json['title'] as String,
          description: json['description'] as String?,
          questionCount: json['questionCount'] as int? ??
              ((json['questionIds'] as List?)?.length ?? 0),
          timeLimitMinutes: json['timeLimitMinutes'] as int? ?? 0,
          questionIds: (json['questionIds'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              const [],
          createdAt: DateTime.parse(json['createdAt'] as String),
          published: json['published'] as bool? ?? true,
        ),
      );
    }
  }

  final subjectsRaw = pack['subjects'] as List<dynamic>? ?? const [];
  final parserConfigs = <String, TopicTestConfig>{};
  for (final s in subjectsRaw) {
    final subject = Map<String, dynamic>.from(s as Map);
    for (final t in (subject['topics'] as List<dynamic>? ?? const [])) {
      final topic = Map<String, dynamic>.from(t as Map);
      final topicId = topic['slug'] as String;
      for (final type in KpssType.values) {
        parserConfigs['${type.name}_$topicId'] = TopicTestConfig(
          topicId: topicId,
          kpssType: type,
          questionsPerTest: topic['questions_per_test'] as int? ?? 20,
          timeLimitMinutes: topic['time_limit_minutes'] as int? ?? 0,
          shuffleQuestions: topic['shuffle_questions'] as bool? ?? true,
          shuffleOptions: topic['shuffle_options'] as bool? ?? true,
          showSolutionAfterEach:
              topic['show_solution_after_each'] as bool? ?? false,
        );
      }
    }
  }

  final parserLessons = (pack['lessons'] as List<dynamic>? ?? const [])
      .map(
        (e) => TopicLessonModel.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList();
  final parserSummary = (pack['summaryCards'] as List<dynamic>? ?? const [])
      .map(
        (e) => TopicSummaryCardModel.fromJson(
          Map<String, dynamic>.from(e as Map),
        ),
      )
      .toList();

  int? packVersion;
  final version = pack['version'];
  if (version is int) {
    packVersion = version;
  } else if (version is num) {
    packVersion = version.toInt();
  }

  return ContentPackMetadataParsed(
    tests: parserTests,
    configs: parserConfigs,
    lessons: parserLessons,
    summaryCards: parserSummary,
    packVersion: packVersion,
  );
}

List<QuestionModel> parseQuestionMaps(List<dynamic> rawList) {
  return [
    for (final e in rawList)
      QuestionModel.fromJson(Map<String, dynamic>.from(e as Map)),
  ];
}

/// Büyük listeleri UI thread dışında jsonEncode.
String encodeJsonMaps(List<Map<String, dynamic>> maps) => jsonEncode(maps);

String encodeJsonMap(Map<String, dynamic> map) => jsonEncode(map);

/// toJson + encode tek isolate turunda.
String encodeQuestionsJson(List<QuestionModel> questions) {
  return jsonEncode([for (final q in questions) q.toJson()]);
}

List<QuestionModel> parseQuestionListJson(String raw) {
  if (raw.isEmpty) return const [];
  final list = jsonDecode(raw) as List<dynamic>;
  return parseQuestionMaps(list);
}

/// HTTP gövdesi → Map (syncCatalog).
Map<String, dynamic> decodeJsonUtf8Bytes(List<int> bytes) {
  return Map<String, dynamic>.from(
    jsonDecode(utf8.decode(bytes)) as Map,
  );
}
