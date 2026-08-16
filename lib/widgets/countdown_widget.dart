import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum KpssType { lisans, onLisans, ortaogretim }

/// Sayaç / hedef sınav — panelden eklenen tipler + yerel yedekler.
class ExamTrack {
  final String id;
  final String label;
  final String shortLabel;
  final String description;
  final DateTime examDate;
  final bool yearlyRepeat;
  final bool evenYearsOnly;
  final String contentTypeName;
  final String iconKey;
  final int sortOrder;
  final bool isActive;

  const ExamTrack({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.description,
    required this.examDate,
    this.yearlyRepeat = true,
    this.evenYearsOnly = false,
    this.contentTypeName = 'lisans',
    this.iconKey = 'school',
    this.sortOrder = 0,
    this.isActive = true,
  });

  static final defaults = <ExamTrack>[
    ExamTrack(
      id: 'kpssLisans',
      label: 'KPSS Lisans',
      shortLabel: 'KPSS Lisans',
      description: 'Genel Yetenek · Genel Kültür',
      examDate: DateTime(2026, 9, 6),
      contentTypeName: 'lisans',
      iconKey: 'school',
      sortOrder: 10,
    ),
    ExamTrack(
      id: 'kpssOnLisans',
      label: 'KPSS Ön Lisans',
      shortLabel: 'Ön Lisans',
      description: 'Ön lisans KPSS oturumu',
      examDate: DateTime(2026, 10, 4),
      contentTypeName: 'onLisans',
      evenYearsOnly: true,
      iconKey: 'book',
      sortOrder: 20,
    ),
    ExamTrack(
      id: 'kpssOrtaogretim',
      label: 'KPSS Ortaöğretim',
      shortLabel: 'Ortaöğretim',
      description: 'Ortaöğretim KPSS oturumu',
      examDate: DateTime(2026, 10, 25),
      contentTypeName: 'ortaogretim',
      evenYearsOnly: true,
      iconKey: 'stories',
      sortOrder: 30,
    ),
    ExamTrack(
      id: 'ags',
      label: 'AGS',
      shortLabel: 'AGS',
      description: 'Akademi Giriş Sınavı',
      examDate: DateTime(2026, 7, 26),
      contentTypeName: 'lisans',
      iconKey: 'premium',
      sortOrder: 40,
    ),
    ExamTrack(
      id: 'ales',
      label: 'ALES',
      shortLabel: 'ALES',
      description: 'Sıradaki oturum · ALES/3',
      examDate: DateTime(2026, 11, 29),
      yearlyRepeat: false,
      contentTypeName: 'lisans',
      iconKey: 'star',
      sortOrder: 50,
    ),
    ExamTrack(
      id: 'dgs',
      label: 'DGS',
      shortLabel: 'DGS',
      description: 'Dikey Geçiş Sınavı',
      examDate: DateTime(2026, 7, 19),
      yearlyRepeat: false,
      contentTypeName: 'lisans',
      iconKey: 'school',
      sortOrder: 60,
    ),
  ];

  KpssType get contentType {
    return KpssType.values.firstWhere(
      (t) => t.name == contentTypeName,
      orElse: () => KpssType.lisans,
    );
  }

  IconData get icon {
    return switch (iconKey) {
      'book' => Icons.menu_book_rounded,
      'stories' => Icons.auto_stories_rounded,
      'premium' => Icons.workspace_premium_outlined,
      'event' => Icons.event_rounded,
      'star' => Icons.star_outline_rounded,
      'balance' => Icons.balance,
      'military' => Icons.account_balance_rounded,
      _ => Icons.school_rounded,
    };
  }

  bool get skipsOddYears {
    if (evenYearsOnly) return true;
    return contentTypeName == 'onLisans' || contentTypeName == 'ortaogretim';
  }

  /// Tek seferlik tarih geçtiyse yeni resmi takvim beklenir.
  bool hasUpcomingDate([DateTime? from]) {
    if (yearlyRepeat || skipsOddYears) return true;
    final now = from ?? DateTime.now();
    final dayAfterExam =
        DateTime(examDate.year, examDate.month, examDate.day + 1);
    return dayAfterExam.isAfter(now);
  }

  DateTime nextExamDate([DateTime? from]) {
    final now = from ?? DateTime.now();
    var target = DateTime(examDate.year, examDate.month, examDate.day);
    if (!yearlyRepeat && !skipsOddYears) return target;
    while (!target.isAfter(now) || (skipsOddYears && target.year.isOdd)) {
      target = DateTime(target.year + 1, target.month, target.day);
    }
    return target;
  }

  factory ExamTrack.fromJson(Map<String, dynamic> json) {
    final rawDate = '${json['examDate'] ?? ''}';
    final parsed = DateTime.tryParse(rawDate) ?? DateTime(2026, 9, 6);
    return ExamTrack(
      id: '${json['id'] ?? json['slug'] ?? ''}',
      label: '${json['name'] ?? json['label'] ?? 'Sınav'}',
      shortLabel: '${json['shortName'] ?? json['name'] ?? 'Sınav'}',
      description: '${json['description'] ?? ''}',
      examDate: DateTime(parsed.year, parsed.month, parsed.day),
      yearlyRepeat: json['yearlyRepeat'] as bool? ?? true,
      evenYearsOnly: json['evenYearsOnly'] as bool? ??
          ('${json['contentType'] ?? ''}' == 'onLisans' ||
              '${json['contentType'] ?? ''}' == 'ortaogretim'),
      contentTypeName: '${json['contentType'] ?? 'lisans'}',
      iconKey: '${json['iconKey'] ?? 'school'}',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': label,
        'shortName': shortLabel,
        'description': description,
        'examDate':
            '${examDate.year.toString().padLeft(4, '0')}-${examDate.month.toString().padLeft(2, '0')}-${examDate.day.toString().padLeft(2, '0')}',
        'yearlyRepeat': yearlyRepeat,
        'evenYearsOnly': evenYearsOnly,
        'contentType': contentTypeName,
        'iconKey': iconKey,
        'sortOrder': sortOrder,
        'isActive': isActive,
      };

  @override
  bool operator ==(Object other) => other is ExamTrack && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

extension KpssTypeExtension on KpssType {
  String get label {
    switch (this) {
      case KpssType.lisans:
        return 'KPSS Lisans';
      case KpssType.onLisans:
        return 'KPSS Ön Lisans';
      case KpssType.ortaogretim:
        return 'KPSS Ortaöğretim';
    }
  }

  DateTime examDate(int year) {
    switch (this) {
      case KpssType.lisans:
        return DateTime(year, 9, 6);
      case KpssType.onLisans:
        return DateTime(year, 10, 4);
      case KpssType.ortaogretim:
        return DateTime(year, 10, 25);
    }
  }

  /// Bir sonraki sınav tarihi (geçtiyse sonraki oturum).
  /// Ön lisans / ortaöğretim yalnızca çift yıllarda.
  DateTime nextExamDate([DateTime? from]) {
    final now = from ?? DateTime.now();
    var year = now.year;
    var target = examDate(year);
    final evenOnly =
        this == KpssType.onLisans || this == KpssType.ortaogretim;
    while (!target.isAfter(now) || (evenOnly && target.year.isOdd)) {
      year += 1;
      target = examDate(year);
    }
    return target;
  }

  String get shortLabel {
    switch (this) {
      case KpssType.lisans:
        return 'Lisans';
      case KpssType.onLisans:
        return 'Ön Lisans';
      case KpssType.ortaogretim:
        return 'Ortaöğretim';
    }
  }
}

/// Sınav geri sayımı — kompakt atmosferik panel.
class CountdownWidget extends StatefulWidget {
  final ExamTrack examTrack;
  /// Açık (krem) arka planlarda ink renkleri kullan.
  final bool light;
  /// Daha küçük padding / tipografi (varsayılan: true).
  final bool compact;
  /// Üst panel içinde — dış kutu/border olmadan sadece içerik.
  final bool embedded;
  /// "SINAVA KALAN" başlığını göster.
  final bool showLabel;
  /// Sağ sütunda tek satır yatay sayaç (panel).
  final bool trailing;

  const CountdownWidget({
    super.key,
    required this.examTrack,
    this.light = false,
    this.compact = true,
    this.embedded = false,
    this.showLabel = true,
    this.trailing = false,
  });

  factory CountdownWidget.forKpssType({
    Key? key,
    required KpssType kpssType,
    bool light = false,
    bool compact = true,
    bool embedded = false,
    bool showLabel = true,
    bool trailing = false,
  }) {
    return CountdownWidget(
      key: key,
      examTrack: ExamTrack.defaults.firstWhere(
        (t) => t.contentType == kpssType,
        orElse: () => ExamTrack.defaults.first,
      ),
      light: light,
      compact: compact,
      embedded: embedded,
      showLabel: showLabel,
      trailing: trailing,
    );
  }

  @override
  State<CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<CountdownWidget> {
  late Duration _remaining;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _remaining = _calculateRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _remaining = _calculateRemaining());
    });
  }

  @override
  void didUpdateWidget(CountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.examTrack != widget.examTrack) {
      _remaining = _calculateRemaining();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration _calculateRemaining() {
    final now = DateTime.now();
    if (!widget.examTrack.hasUpcomingDate(now)) return Duration.zero;
    final remaining = widget.examTrack.nextExamDate(now).difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours.remainder(24);
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);
    final light = widget.light;
    final darkPage = light && AppTheme.isDark(context);
    final compact = widget.compact;
    final trailing = widget.trailing;
    final hasUpcomingDate = widget.examTrack.hasUpcomingDate();

    Widget timeRow({
      required bool mainAxisMin,
      MainAxisAlignment alignment = MainAxisAlignment.center,
    }) {
      return Row(
        mainAxisSize: mainAxisMin ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: alignment,
        children: [
          _TimeBlock(
            value: days,
            label: 'Gün',
            light: light,
            compact: compact,
            emphasized: true,
            tight: trailing,
          ),
          _DividerDot(light: light, compact: compact, tight: trailing),
          _TimeBlock(
            value: hours,
            label: 'Saat',
            light: light,
            compact: compact,
            tight: trailing,
          ),
          _DividerDot(light: light, compact: compact, tight: trailing),
          _TimeBlock(
            value: minutes,
            label: 'Dk',
            light: light,
            compact: compact,
            tight: trailing,
          ),
          _DividerDot(light: light, compact: compact, tight: trailing),
          _TimeBlock(
            value: seconds,
            label: 'Sn',
            light: light,
            compact: compact,
            tight: trailing,
          ),
        ],
      );
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          trailing ? CrossAxisAlignment.end : CrossAxisAlignment.center,
      children: [
        if (widget.showLabel) ...[
          ShimmerCountdownLabel(compact: compact),
          SizedBox(height: compact ? 4 : 8),
        ],
        if (hasUpcomingDate)
          timeRow(mainAxisMin: true)
        else
          Text(
            'Tarih bekleniyor',
            textAlign: trailing ? TextAlign.right : TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w700,
              color: light
                  ? AppTheme.onPage(context)
                  : AppTheme.champagneLight,
            ),
          ),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Center(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          compact ? 10 : 12,
          compact ? 6 : 8,
          compact ? 10 : 12,
          compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
          border: Border.all(
            color: light
                ? AppTheme.champagne.withValues(alpha: darkPage ? 0.45 : 0.35)
                : Colors.white.withValues(alpha: 0.1),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: light
                ? (darkPage
                    ? [
                        AppTheme.inkSoft.withValues(alpha: 0.95),
                        AppTheme.champagne.withValues(alpha: 0.12),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.9),
                        AppTheme.champagne.withValues(alpha: 0.08),
                      ])
                : [
                    Colors.white.withValues(alpha: 0.07),
                    Colors.white.withValues(alpha: 0.02),
                  ],
          ),
        ),
        child: content,
      ),
    );
  }
}

/// "SINAVA KALAN" — büyük tipografi + soldan sağa akan ışık.
class ShimmerCountdownLabel extends StatefulWidget {
  final bool compact;
  final TextAlign textAlign;

  const ShimmerCountdownLabel({
    super.key,
    this.compact = true,
    this.textAlign = TextAlign.center,
  });

  @override
  State<ShimmerCountdownLabel> createState() => _ShimmerCountdownLabelState();
}

class _ShimmerCountdownLabelState extends State<ShimmerCountdownLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _labelStyle = TextStyle(
    fontWeight: FontWeight.w800,
    letterSpacing: 1.8,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.compact ? 15.0 : 20.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Soldan sağa akan dar ışık bandı.
        final sweep = _controller.value * 2.6 - 0.8;

        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(sweep - 0.22, 0),
              end: Alignment(sweep + 0.22, 0),
              colors: [
                AppTheme.champagne.withValues(alpha: 0.55),
                AppTheme.champagne.withValues(alpha: 0.9),
                AppTheme.champagneLight,
                Colors.white,
                AppTheme.champagneLight,
                AppTheme.champagne.withValues(alpha: 0.9),
                AppTheme.champagne.withValues(alpha: 0.55),
              ],
              stops: const [0.0, 0.36, 0.44, 0.5, 0.56, 0.64, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Text(
        'SINAVA KALAN',
        textAlign: widget.textAlign,
        style: _labelStyle.copyWith(
          fontSize: fontSize,
          color: AppTheme.champagne,
        ),
      ),
    );
  }
}

class _DividerDot extends StatelessWidget {
  final bool light;
  final bool compact;
  final bool tight;

  const _DividerDot({
    this.light = false,
    this.compact = true,
    this.tight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tight ? 2 : (compact ? 3 : 6)),
      child: Text(
        '·',
        style: TextStyle(
          color: AppTheme.champagne.withValues(alpha: light ? 0.55 : 0.5),
          fontSize: compact ? 12 : 18,
        ),
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  final int value;
  final String label;
  final bool light;
  final bool compact;
  final bool emphasized;
  final bool tight;

  const _TimeBlock({
    required this.value,
    required this.label,
    this.light = false,
    this.compact = true,
    this.emphasized = false,
    this.tight = false,
  });

  @override
  Widget build(BuildContext context) {
    final onLightPage = light;
    final valueColor = onLightPage
        ? AppTheme.onPage(context)
        : Colors.white;
    final labelColor = onLightPage
        ? AppTheme.mutedOnPage(context)
        : Colors.white.withValues(alpha: 0.45);

    final valueSize = emphasized
        ? (tight ? 18.0 : (compact ? 20.0 : 26.0))
        : (tight ? 14.0 : (compact ? 16.0 : 22.0));
    final labelSize = emphasized
        ? (tight ? 8.5 : (compact ? 9.5 : 11.0))
        : (tight ? 7.5 : (compact ? 8.0 : 10.0));
    final blockWidth = tight ? 34.0 : null;

    return SizedBox(
      width: blockWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: valueColor,
              fontSize: valueSize,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
              height: 1,
              letterSpacing: -1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: compact ? 1 : 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: labelColor,
              fontSize: labelSize,
              fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
