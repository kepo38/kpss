import 'dart:async';

import 'package:flutter/material.dart';

import '../data/kpss_curriculum.dart';
import '../services/content_bank_service.dart';
import '../theme/app_theme.dart';
import 'countdown_widget.dart';

/// Günlük görev dersleri (Güncel Bilgiler hariç).
const _missionSubjectIds = [
  'turkce',
  'matematik',
  'tarih',
  'cografya',
  'vatandaslik',
];

/// Ana ekran — Bugünkü KPSS Görev Merkezi.
class DailyMissionCenter extends StatefulWidget {
  final KpssType kpssType;
  final ValueChanged<KpssSubject>? onSubjectTap;

  const DailyMissionCenter({
    super.key,
    required this.kpssType,
    this.onSubjectTap,
  });

  @override
  State<DailyMissionCenter> createState() => _DailyMissionCenterState();
}

class _DailyMissionCenterState extends State<DailyMissionCenter>
    with SingleTickerProviderStateMixin {
  late DateTime _day;
  Timer? _midnightWatch;
  late final AnimationController _collapse;
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _day = _today();
    _collapse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1,
    );
    ContentBankService.instance.addListener(_onBankChanged);
    // Gece 00:00 geçince barları sıfırlamak için gün değişimini izle.
    _midnightWatch = Timer.periodic(const Duration(seconds: 30), (_) {
      final now = _today();
      if (now.year != _day.year ||
          now.month != _day.month ||
          now.day != _day.day) {
        if (mounted) setState(() => _day = now);
      }
    });
  }

  @override
  void dispose() {
    _midnightWatch?.cancel();
    _collapse.dispose();
    ContentBankService.instance.removeListener(_onBankChanged);
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _collapse.forward();
    } else {
      _collapse.reverse();
    }
  }

  void _onBankChanged() {
    if (mounted) setState(() {});
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  List<KpssSubject> get _subjects {
    final all = KpssCurriculum.subjectsFor(widget.kpssType);
    return all.where((s) => _missionSubjectIds.contains(s.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bank = ContentBankService.instance;
    final subjects = _subjects;
    final doneCount = subjects
        .where((s) => bank.dailyCompletedTestsForSubject(widget.kpssType, s.id) > 0)
        .length;
    final total = subjects.length;
    final progress = total == 0 ? 0.0 : doneCount / total;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.38),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.94),
            AppTheme.champagne.withValues(alpha: 0.1),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(14, 12, 14, _expanded ? 0 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 28),
                      child: Text(
                        'Bugünkü Ödevin: $doneCount / $total',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: AppTheme.onPage(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doneCount == total
                          ? 'Tüm görevler tamamlandı'
                          : '%${(progress * 100).round()} Tamamlandı',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.mutedOnPage(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _OverallProgressBar(
                      progress: progress,
                      complete: doneCount == total,
                    ),
                  ],
                ),
              ),
              SizeTransition(
                sizeFactor: CurvedAnimation(
                  parent: _collapse,
                  curve: Curves.easeInOutCubic,
                ),
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < subjects.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _SubjectMissionRow(
                          subject: subjects[i],
                          completed: bank.dailyCompletedTestsForSubject(
                                widget.kpssType,
                                subjects[i].id,
                              ) >
                              0,
                          remainingQuota: _remainingQuota(bank, subjects[i].id),
                          onTap: () => widget.onSubjectTap?.call(subjects[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 6,
            right: 6,
            child: _CollapseHandle(
              expanded: _expanded,
              onTap: _toggleExpanded,
            ),
          ),
        ],
      ),
    );
  }

  int _remainingQuota(ContentBankService bank, String subjectId) {
    final completed =
        bank.dailyCompletedTestsForSubject(widget.kpssType, subjectId);
    final allowance =
        bank.dailyTestAllowanceForSubject(widget.kpssType, subjectId);
    return (allowance - completed).clamp(0, allowance);
  }
}

class _CollapseHandle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _CollapseHandle({
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedRotation(
            turns: expanded ? 0 : 0.5,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            child: CustomPaint(
              size: const Size(20, 10),
              painter: _TrianglePainter(
                color: AppTheme.mutedOnPage(context).withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.5, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.18), 3, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _OverallProgressBar extends StatelessWidget {
  final double progress;
  final bool complete;

  const _OverallProgressBar({
    required this.progress,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    final fill = complete
        ? const Color(0xFF22C55E)
        : AppTheme.champagne;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppTheme.ink.withValues(alpha: 0.08),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: complete
                            ? const [
                                Color(0xFF4ADE80),
                                Color(0xFF16A34A),
                              ]
                            : [
                                AppTheme.champagneLight,
                                fill,
                              ],
                      ),
                      boxShadow: complete
                          ? [
                              BoxShadow(
                                color: const Color(0xFF22C55E)
                                    .withValues(alpha: 0.45),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectMissionRow extends StatefulWidget {
  final KpssSubject subject;
  final bool completed;
  final int remainingQuota;
  final VoidCallback? onTap;

  const _SubjectMissionRow({
    required this.subject,
    required this.completed,
    required this.remainingQuota,
    this.onTap,
  });

  @override
  State<_SubjectMissionRow> createState() => _SubjectMissionRowState();
}

class _SubjectMissionRowState extends State<_SubjectMissionRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill;
  late bool _wasCompleted;

  @override
  void initState() {
    super.initState();
    _wasCompleted = widget.completed;
    _fill = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: widget.completed ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(_SubjectMissionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completed && !_wasCompleted) {
      _fill.forward(from: 0);
    } else if (!widget.completed && _wasCompleted) {
      _fill.value = 0;
    } else if (widget.completed) {
      _fill.value = 1;
    }
    _wasCompleted = widget.completed;
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.onPage(context);
    final actionColor = widget.completed
        ? const Color(0xFF15803D)
        : AppTheme.champagne.withValues(alpha: 0.95);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.completed ? null : widget.onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: AppTheme.champagne.withValues(alpha: 0.14),
        highlightColor: AppTheme.champagne.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.subject.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.15,
                        color: ink.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                  if (widget.completed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              const Color(0xFF22C55E).withValues(alpha: 0.55),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TAMAMLANDI',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: Color(0xFF15803D),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.remainingQuota > 0
                              ? 'Görevi Yap · ${widget.remainingQuota} Test'
                              : 'Görevi Yap',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                            color: actionColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: actionColor,
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 5),
              AnimatedBuilder(
                animation: _fill,
                builder: (context, _) {
                  final t = widget.completed ? _fill.value : 0.0;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: AppTheme.ink.withValues(alpha: 0.1),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: t.clamp(0.0, 1.0),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color.lerp(
                                      const Color(0xFF86EFAC),
                                      const Color(0xFF22C55E),
                                      t,
                                    )!,
                                    Color.lerp(
                                      const Color(0xFF4ADE80),
                                      const Color(0xFF15803D),
                                      t,
                                    )!,
                                  ],
                                ),
                                boxShadow: t > 0.85
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF22C55E)
                                              .withValues(alpha: 0.55 * t),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
