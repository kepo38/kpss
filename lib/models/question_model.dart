class QuestionModel {
  final String id;
  final String dersAdi;
  final String konuAdi;
  final String altKonuAdi;
  final String soruMetni;
  final String? imageUrl;
  /// `above` | `below` — soru görselinin metne göre konumu.
  final String stemImagePosition;
  final String? sekilKodu;
  final Map<String, String> siklar;
  final bool optionsAreImages;
  final Map<String, String?> optionImageUrls;
  final String optionTable;
  final String dogruCevap;
  final String cozumMetni;
  final String? cozumImageUrl;
  final int hataBildirimSayisi;
  final DateTime guncellenmeTarihi;
  final bool osymSordu;
  final String difficulty;
  final int attemptCount;
  final int viewCount;
  final double? correctRate;
  final bool difficultyVisible;
  final String? scenarioId;
  final String? scenarioTitle;
  final String? scenarioStem;
  final int scenarioOrder;

  const QuestionModel({
    required this.id,
    required this.dersAdi,
    required this.konuAdi,
    required this.altKonuAdi,
    required this.soruMetni,
    this.imageUrl,
    this.stemImagePosition = 'below',
    this.sekilKodu,
    required this.siklar,
    this.optionsAreImages = false,
    this.optionImageUrls = const {},
    this.optionTable = 'none',
    required this.dogruCevap,
    required this.cozumMetni,
    this.cozumImageUrl,
    this.hataBildirimSayisi = 0,
    required this.guncellenmeTarihi,
    this.osymSordu = false,
    this.difficulty = 'medium',
    this.attemptCount = 0,
    this.viewCount = 0,
    this.correctRate,
    this.difficultyVisible = false,
    this.scenarioId,
    this.scenarioTitle,
    this.scenarioStem,
    this.scenarioOrder = 0,
  });

  String? optionImageUrlFor(String key) {
    if (!optionsAreImages) return null;
    final direct = optionImageUrls[key];
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    return null;
  }

  bool get hasVisualOptions =>
      optionsAreImages &&
      optionImageUrls.values.any((u) => u != null && u.trim().isNotEmpty);

  static bool _keepDisplayMathDelimiters(String inner) {
    final t = inner.trim();
    if (t.isEmpty) return false;
    return t.contains(r'\begin{') ||
        t.contains(r'\hline') ||
        t.contains(r'\frac') ||
        t.contains(r'\dfrac') ||
        t.contains(r'\tfrac') ||
        t.contains(r'\sqrt') ||
        t.contains(r'\displaystyle') ||
        t.contains(r'\sum') ||
        t.contains(r'\int') ||
        RegExp(r'\\over(?![a-zA-Z])').hasMatch(t);
  }

  static String _normalizeLatexDelimiters(String input) {
    var text = input.trim();
    if (text.isEmpty) return text;
    // \(...\), \[...\] -> $...$, $$...$$
    text = text.replaceAllMapped(
      RegExp(r'\\\(([\s\S]+?)\\\)'),
      (m) => '\$${m.group(1)!.trim()}\$',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\\[([\s\S]+?)\\\]'),
      (m) => '\$\$${m.group(1)!.trim()}\$\$',
    );
    // Gemini bazen kısa ifadeleri $$...$$ döndürebiliyor; display blokları koru.
    text = text.replaceAllMapped(
      RegExp(r'\$\$([^\n$]+?)\$\$'),
      (m) {
        final inner = m.group(1)!.trim();
        if (_keepDisplayMathDelimiters(inner)) {
          return '\$\$${inner}\$\$';
        }
        return '\$${inner}\$';
      },
    );
    return text;
  }

  static String _parseStemImagePosition(Map<String, dynamic> json) {
    final raw = json['stemImagePosition'] ?? json['stem_image_position'];
    if (raw == 'above') return 'above';
    return 'below';
  }

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final rawSvg = (json['sekilKodu'] as String?)?.trim();
    final rawStem = (json['soruMetni'] as String? ?? '');
    final rawOptions = Map<String, String>.from(json['siklar'] as Map);
    final normalizedOptions = {
      for (final e in rawOptions.entries) e.key: _normalizeLatexDelimiters(e.value),
    };
    final rawImages = json['optionImageUrls'];
    final optionImages = <String, String?>{};
    if (rawImages is Map) {
      for (final e in rawImages.entries) {
        final v = e.value;
        optionImages[e.key.toString()] =
            v == null ? null : v.toString().trim();
      }
    }
    for (final key in const ['A', 'B', 'C', 'D', 'E']) {
      final alt = json['option${key}ImageUrl'] ?? json['option${key}_image_url'];
      if (alt is String && alt.trim().isNotEmpty) {
        optionImages[key] = alt.trim();
      }
    }
    final rawSolutionImage = json['cozumImageUrl'] as String?;
    return QuestionModel(
      id: json['id'] as String,
      dersAdi: json['dersAdi'] as String,
      konuAdi: json['konuAdi'] as String,
      altKonuAdi: json['altKonuAdi'] as String,
      soruMetni: _normalizeLatexDelimiters(rawStem),
      imageUrl: json['imageUrl'] as String?,
      stemImagePosition: _parseStemImagePosition(json),
      sekilKodu: (rawSvg == null || rawSvg.isEmpty) ? null : rawSvg,
      siklar: normalizedOptions,
      optionsAreImages: json['optionsAreImages'] as bool? ??
          json['options_are_images'] as bool? ??
          false,
      optionImageUrls: optionImages,
      optionTable: json['optionTable'] as String? ?? 'none',
      dogruCevap: json['dogruCevap'] as String,
      cozumMetni: _normalizeLatexDelimiters(json['cozumMetni'] as String),
      cozumImageUrl: rawSolutionImage == null || rawSolutionImage.trim().isEmpty
          ? null
          : rawSolutionImage.trim(),
      hataBildirimSayisi: json['hataBildirimSayisi'] as int? ?? 0,
      guncellenmeTarihi: DateTime.parse(json['guncellenmeTarihi'] as String),
      osymSordu: json['osymSordu'] as bool? ?? false,
      difficulty: json['difficulty'] as String? ?? 'medium',
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      correctRate: (json['correctRate'] as num?)?.toDouble() ??
          (json['correct_rate'] as num?)?.toDouble(),
      difficultyVisible: json['difficultyVisible'] as bool? ?? false,
      scenarioId: json['scenarioId'] as String?,
      scenarioTitle: json['scenarioTitle'] as String?,
      scenarioStem: (json['scenarioStem'] as String?) == null
          ? null
          : _normalizeLatexDelimiters(json['scenarioStem'] as String),
      scenarioOrder: (json['scenarioOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dersAdi': dersAdi,
        'konuAdi': konuAdi,
        'altKonuAdi': altKonuAdi,
        'soruMetni': soruMetni,
        'imageUrl': imageUrl,
        'stemImagePosition': stemImagePosition,
        'sekilKodu': sekilKodu,
        'siklar': siklar,
        'optionsAreImages': optionsAreImages,
        'optionImageUrls': optionImageUrls,
        'optionTable': optionTable,
        'dogruCevap': dogruCevap,
        'cozumMetni': cozumMetni,
        'cozumImageUrl': cozumImageUrl,
        'hataBildirimSayisi': hataBildirimSayisi,
        'guncellenmeTarihi': guncellenmeTarihi.toIso8601String(),
        'osymSordu': osymSordu,
        'difficulty': difficulty,
        'attemptCount': attemptCount,
        'viewCount': viewCount,
        'correctRate': correctRate,
        'difficultyVisible': difficultyVisible,
        'scenarioId': scenarioId,
        'scenarioTitle': scenarioTitle,
        'scenarioStem': scenarioStem,
        'scenarioOrder': scenarioOrder,
      };

  QuestionModel copyWith({
    String? id,
    String? dersAdi,
    String? konuAdi,
    String? altKonuAdi,
    String? soruMetni,
    String? imageUrl,
    String? stemImagePosition,
    String? sekilKodu,
    Map<String, String>? siklar,
    bool? optionsAreImages,
    Map<String, String?>? optionImageUrls,
    String? optionTable,
    String? dogruCevap,
    String? cozumMetni,
    String? cozumImageUrl,
    int? hataBildirimSayisi,
    DateTime? guncellenmeTarihi,
    bool? osymSordu,
    String? difficulty,
    int? attemptCount,
    int? viewCount,
    double? correctRate,
    bool? difficultyVisible,
    String? scenarioId,
    String? scenarioTitle,
    String? scenarioStem,
    int? scenarioOrder,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      dersAdi: dersAdi ?? this.dersAdi,
      konuAdi: konuAdi ?? this.konuAdi,
      altKonuAdi: altKonuAdi ?? this.altKonuAdi,
      soruMetni: soruMetni ?? this.soruMetni,
      imageUrl: imageUrl ?? this.imageUrl,
      stemImagePosition: stemImagePosition ?? this.stemImagePosition,
      sekilKodu: sekilKodu ?? this.sekilKodu,
      siklar: siklar ?? this.siklar,
      optionsAreImages: optionsAreImages ?? this.optionsAreImages,
      optionImageUrls: optionImageUrls ?? this.optionImageUrls,
      optionTable: optionTable ?? this.optionTable,
      dogruCevap: dogruCevap ?? this.dogruCevap,
      cozumMetni: cozumMetni ?? this.cozumMetni,
      cozumImageUrl: cozumImageUrl ?? this.cozumImageUrl,
      hataBildirimSayisi: hataBildirimSayisi ?? this.hataBildirimSayisi,
      guncellenmeTarihi: guncellenmeTarihi ?? this.guncellenmeTarihi,
      osymSordu: osymSordu ?? this.osymSordu,
      difficulty: difficulty ?? this.difficulty,
      attemptCount: attemptCount ?? this.attemptCount,
      viewCount: viewCount ?? this.viewCount,
      correctRate: correctRate ?? this.correctRate,
      difficultyVisible: difficultyVisible ?? this.difficultyVisible,
      scenarioId: scenarioId ?? this.scenarioId,
      scenarioTitle: scenarioTitle ?? this.scenarioTitle,
      scenarioStem: scenarioStem ?? this.scenarioStem,
      scenarioOrder: scenarioOrder ?? this.scenarioOrder,
    );
  }

  bool get hasScenarioPassage =>
      scenarioStem != null && scenarioStem!.trim().isNotEmpty;

  /// TG deneme ekranı — havuzdan gelen sorularda ÖSYM damgası gösterilmez.
  QuestionModel forTgExamDisplay() => copyWith(osymSordu: false);

  static List<QuestionModel> forTgExamDisplayList(
    List<QuestionModel> questions,
  ) =>
      questions.map((q) => q.forTgExamDisplay()).toList(growable: false);

  static List<QuestionModel> keepGroupsContiguous(List<QuestionModel> questions) {
    if (questions.length < 2) return questions;
    final members = <String, List<QuestionModel>>{};
    for (final q in questions) {
      final id = q.scenarioId;
      if (id == null || id.isEmpty) continue;
      members.putIfAbsent(id, () => []).add(q);
    }
    if (members.isEmpty) return questions;
    for (final group in members.values) {
      group.sort((a, b) {
        final byOrder = a.scenarioOrder.compareTo(b.scenarioOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    }
    final emitted = <String>{};
    final out = <QuestionModel>[];
    for (final q in questions) {
      final sid = q.scenarioId;
      if (sid == null || sid.isEmpty) {
        out.add(q);
        continue;
      }
      if (!emitted.add(sid)) continue;
      out.addAll(members[sid]!);
    }
    return out;
  }

  static const osymPerTest = 4;
  static const plainBeforeOsym = 4;

  /// Her 4 etiketsiz sorudan sonra 1 ÖSYM SORDU (testte en fazla 4).
  /// Etiketsiz yetmezse kalan sorular normal sırada eklenir; olay grubu bölünmez.
  static List<QuestionModel> interleaveOsymSordu(List<QuestionModel> questions) {
    if (questions.length < 2) return questions;
    final grouped = keepGroupsContiguous(questions);
    final blocks = <List<QuestionModel>>[];
    var i = 0;
    while (i < grouped.length) {
      final current = grouped[i];
      final sid = current.scenarioId;
      if (sid == null || sid.isEmpty) {
        blocks.add([current]);
        i += 1;
        continue;
      }
      var end = i + 1;
      while (end < grouped.length && grouped[end].scenarioId == sid) {
        end += 1;
      }
      blocks.add(grouped.sublist(i, end));
      i = end;
    }

    bool isOsym(List<QuestionModel> block) =>
        block.any((q) => q.osymSordu);

    final osymBlocks = blocks.where(isOsym).toList();
    final plainBlocks = blocks.where((b) => !isOsym(b)).toList();
    if (osymBlocks.isEmpty || plainBlocks.isEmpty) return grouped;

    final osymUse = <List<QuestionModel>>[];
    final osymRest = <List<QuestionModel>>[];
    var osymCount = 0;
    for (final block in osymBlocks) {
      if (osymCount >= osymPerTest) {
        osymRest.add(block);
        continue;
      }
      osymUse.add(block);
      osymCount += block.length;
    }

    final out = <QuestionModel>[];
    var plainI = 0;
    var osymI = 0;
    var plainSince = 0;
    while (plainI < plainBlocks.length || osymI < osymUse.length) {
      if (osymI < osymUse.length && plainSince >= plainBeforeOsym) {
        out.addAll(osymUse[osymI]);
        osymI += 1;
        plainSince = 0;
        continue;
      }
      if (plainI < plainBlocks.length) {
        final block = plainBlocks[plainI];
        plainI += 1;
        out.addAll(block);
        plainSince += block.length;
        continue;
      }
      break;
    }
    for (final block in osymUse.skip(osymI)) {
      out.addAll(block);
    }
    for (final block in osymRest) {
      out.addAll(block);
    }
    for (final block in plainBlocks.skip(plainI)) {
      out.addAll(block);
    }
    return out;
  }
}
