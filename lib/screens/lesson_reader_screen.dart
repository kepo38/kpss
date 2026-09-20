import 'dart:async';

import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../services/lesson_card_drawing_service.dart';
import '../services/lesson_card_notes_service.dart';
import '../services/lesson_card_progress_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/embossed_app_bar_title.dart';
import '../widgets/favorite_heart_button.dart';
import '../widgets/formatted_text.dart';
import '../widgets/quiz_drawing_overlay.dart';

/// Konu bilgi kartları — Tinder tarzı Unuttum / Biliyorum destesi.
class LessonReaderScreen extends StatefulWidget {
  final String topicName;
  final List<TopicLessonModel> lessons;

  const LessonReaderScreen({
    super.key,
    required this.topicName,
    required this.lessons,
  });

  @override
  State<LessonReaderScreen> createState() => _LessonReaderScreenState();
}

class _LessonReaderScreenState extends State<LessonReaderScreen> {
  static const _maxStrokes = 80;

  double _dragDx = 0;
  bool _busy = false;
  bool _scrollLocked = false;
  double _verticalSlop = 0;
  double _horizontalSlop = 0;
  /// Bu oturumda Unuttum/Biliyorum ile geçilen kartlar (desteden çıkar).
  final Set<String> _sessionPassed = {};

  bool _drawingEnabled = false;
  Color _penColor = QuizPenToolbar.colors.first;
  double _penWidth = QuizPenToolbar.widths[1];
  bool _highlighter = false;
  final Map<String, List<QuizStroke>> _drawings = {};
  final ScrollController _cardScroll = ScrollController();
  String? _loadedLessonId;

  List<TopicLessonModel> get _queue {
    final progress = LessonCardProgressService.instance;
    final pending = widget.lessons
        .where(
          (c) =>
              !progress.isKnown(c.id) && !_sessionPassed.contains(c.id),
        )
        .toList();
    if (pending.isNotEmpty) return pending;
    final rest = widget.lessons
        .where((c) => !_sessionPassed.contains(c.id))
        .toList();
    return rest;
  }

  TopicLessonModel? get _top => _queue.isEmpty ? null : _queue.first;

  @override
  void initState() {
    super.initState();
    unawaited(
      LessonCardDrawingService.instance.initialize().then((_) async {
        if (!mounted) return;
        await _ensureStrokesLoaded(_top?.id);
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      LessonCardNotesService.instance.initialize().then((_) {
        if (mounted) setState(() {});
      }),
    );
    _cardScroll.addListener(() {
      if (_drawingEnabled && mounted) setState(() {});
    });
  }

  Future<void> _openNotesSheet(TopicLessonModel lesson) async {
    await LessonCardNotesService.instance.initialize();
    if (!mounted) return;
    final controller = TextEditingController(
      text: LessonCardNotesService.instance.noteFor(lesson.id),
    );
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121C2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Notlar',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.champagneLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lesson.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 8,
                minLines: 5,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
                cursorColor: AppTheme.champagne,
                decoration: InputDecoration(
                  hintText: 'Bu bilgi kartına not ekle…',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.champagne.withValues(alpha: 0.35),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.champagne.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(
                      'Vazgeç',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.champagne,
                      foregroundColor: AppTheme.ink,
                    ),
                    child: const Text('Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (saved == true) {
      await LessonCardNotesService.instance.save(lesson.id, controller.text);
      if (mounted) setState(() {});
    }
    controller.dispose();
  }

  @override
  void dispose() {
    final id = _top?.id;
    if (id != null) {
      unawaited(_persistLesson(id));
    }
    _cardScroll.dispose();
    super.dispose();
  }

  Future<void> _ensureStrokesLoaded(String? lessonId) async {
    if (lessonId == null) return;
    if (_loadedLessonId == lessonId && _drawings.containsKey(lessonId)) {
      return;
    }
    await LessonCardDrawingService.instance.initialize();
    if (!_drawings.containsKey(lessonId)) {
      _drawings[lessonId] = List<QuizStroke>.from(
        LessonCardDrawingService.instance.strokesFor(lessonId),
      );
    }
    _loadedLessonId = lessonId;
  }

  Future<void> _persistLesson(String lessonId) async {
    await LessonCardDrawingService.instance.saveStrokes(
      lessonId,
      strokes: _drawings[lessonId] ?? const [],
    );
  }

  Future<void> _onStrokeComplete(QuizStroke stroke) async {
    final id = _top?.id;
    if (id == null) return;
    final list = _drawings.putIfAbsent(id, () => <QuizStroke>[]);
    if (list.length >= _maxStrokes) list.removeAt(0);
    list.add(stroke);
    setState(() {});
    await _persistLesson(id);
  }

  Future<void> _onUndo() async {
    final id = _top?.id;
    if (id == null) return;
    final list = _drawings[id];
    if (list == null || list.isEmpty) return;
    setState(() => list.removeLast());
    await _persistLesson(id);
  }

  Future<void> _onClear() async {
    final id = _top?.id;
    if (id == null) return;
    setState(() => _drawings[id] = <QuizStroke>[]);
    await _persistLesson(id);
  }

  Future<void> _resolve({required bool known}) async {
    final card = _top;
    if (card == null || _busy || _drawingEnabled) return;
    await _persistLesson(card.id);
    setState(() {
      _busy = true;
      _dragDx = known ? 420 : -420;
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final progress = LessonCardProgressService.instance;
    if (known) {
      await progress.markKnown(card.id);
    } else {
      await progress.markWeak(card.id);
    }
    if (!mounted) return;
    setState(() {
      _sessionPassed.add(card.id);
      _dragDx = 0;
      _busy = false;
      _scrollLocked = false;
    });
    if (_cardScroll.hasClients) {
      _cardScroll.jumpTo(0);
    }
    await _ensureStrokesLoaded(_top?.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleSpacing: 0,
        leading: AppBackButton.onDark(accent: AppTheme.champagneLight),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: EmbossedAppBarTitle(
            widget.topicName,
            alignLeft: true,
            fontSize: 15,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A2A3E),
                Color(0xFF121C2E),
              ],
            ),
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF162338),
              Color(0xFF0C1424),
              Color(0xFF0A1C22),
              Color(0xFF0E1828),
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -30,
              child: _AtmosphereBlob(
                size: 180,
                color: AppTheme.neonEdge.withValues(alpha: 0.12),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -50,
              child: _AtmosphereBlob(
                size: 220,
                color: AppTheme.neonGold.withValues(alpha: 0.1),
              ),
            ),
            if (widget.lessons.isEmpty)
              Center(
                child: Text(
                  'Bu konu için henüz bilgi kartı yok.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                ),
              )
            else
              SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: ListenableBuilder(
                    listenable: LessonCardProgressService.instance,
                    builder: (context, _) => _buildDeck(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeck(BuildContext context) {
    final card = _top;
    if (widget.lessons.isEmpty) return const SizedBox.shrink();
    if (card == null) {
      return _EmptyDeck(total: widget.lessons.length);
    }

    if (_loadedLessonId != card.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _ensureStrokesLoaded(card.id);
        if (mounted) setState(() {});
      });
    }

    final progress = (_dragDx / 140).clamp(-1.0, 1.0);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final queue = _queue;
    final strokes = _drawings[card.id] ?? const <QuizStroke>[];
    final swipeBlocked = _busy || _scrollLocked || _drawingEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              if (_drawingEnabled)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF132A5C).withValues(alpha: 0.97),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.champagne.withValues(alpha: 0.35),
                      ),
                    ),
                    child: QuizPenToolbar(
                      color: _penColor,
                      width: _penWidth,
                      highlighter: _highlighter,
                      onColor: (c) => setState(() {
                        _penColor = c;
                        _highlighter = false;
                      }),
                      onWidth: (w) => setState(() {
                        _penWidth = w;
                        _highlighter = false;
                      }),
                      onHighlighter: () =>
                          setState(() => _highlighter = true),
                      onUndo: strokes.isEmpty ? null : _onUndo,
                      onClear: _onClear,
                    ),
                  ),
                )
              else
                const Spacer(),
              IconButton(
                tooltip:
                    _drawingEnabled ? 'Çizimi kapat' : 'Kalem (işaretle)',
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _drawingEnabled = !_drawingEnabled;
                          _scrollLocked = _drawingEnabled;
                        }),
                icon: Icon(
                  _drawingEnabled
                      ? Icons.edit_off_outlined
                      : Icons.edit_rounded,
                  color: _drawingEnabled
                      ? AppTheme.champagne
                      : Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            onHorizontalDragStart: swipeBlocked
                ? null
                : (_) {
                    _verticalSlop = 0;
                    _horizontalSlop = 0;
                  },
            onHorizontalDragUpdate: swipeBlocked
                ? null
                : (d) {
                    _verticalSlop += d.delta.dy.abs();
                    _horizontalSlop += d.delta.dx.abs();
                    if (_verticalSlop > 22 &&
                        _verticalSlop > _horizontalSlop * 1.25) {
                      return;
                    }
                    setState(() => _dragDx += d.delta.dx);
                  },
            onHorizontalDragEnd: swipeBlocked
                ? null
                : (d) {
                    if (_dragDx > 110 || (d.primaryVelocity ?? 0) > 700) {
                      _resolve(known: true);
                    } else if (_dragDx < -110 ||
                        (d.primaryVelocity ?? 0) < -700) {
                      _resolve(known: false);
                    } else {
                      setState(() => _dragDx = 0);
                    }
                  },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (queue.length > 1)
                  Positioned.fill(
                    child: Transform.translate(
                      offset: const Offset(0, 8),
                      child: Opacity(
                        opacity: 0.4,
                        child: LessonCardFace(
                          lesson: queue[1],
                          index: 2,
                          total: widget.lessons.length,
                          showHeart: false,
                          showCounter: false,
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(_dragDx, 0),
                    child: Transform.rotate(
                      angle: progress * 0.08,
                      child: Stack(
                        children: [
                          LessonCardFace(
                            lesson: card,
                            index: widget.lessons.indexOf(card) + 1,
                            total: widget.lessons.length,
                            scrollController: _cardScroll,
                            strokes: strokes,
                            drawingEnabled: _drawingEnabled,
                            penColor: _penColor,
                            penWidth: _penWidth,
                            highlighter: _highlighter,
                            onStrokeComplete: _onStrokeComplete,
                            onUndo: _onUndo,
                            onClear: _onClear,
                            onNotesTap: _busy
                                ? null
                                : () => _openNotesSheet(card),
                            onScrollLockChanged: (locked) {
                              if (_drawingEnabled) return;
                              if (_scrollLocked == locked) return;
                              setState(() => _scrollLocked = locked);
                            },
                          ),
                          if (!_drawingEnabled && progress > 0.15)
                            _SwipeStamp(
                              label: 'BİLİYORUM',
                              color: const Color(0xFF34D399),
                              alignment: Alignment.topLeft,
                              opacity: progress,
                            ),
                          if (!_drawingEnabled && progress < -0.15)
                            _SwipeStamp(
                              label: 'UNUTTUM',
                              color: const Color(0xFFF87171),
                              alignment: Alignment.topRight,
                              opacity: -progress,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: EdgeInsets.only(bottom: bottomInset + 12),
          child: _ActionBar(
            busy: _busy || _drawingEnabled,
            drawingHint: _drawingEnabled,
            onForgot: () => _resolve(known: false),
            onKnow: () => _resolve(known: true),
          ),
        ),
      ],
    );
  }
}

class _NotesChip extends StatelessWidget {
  final bool hasNote;
  final VoidCallback? onTap;

  const _NotesChip({
    required this.hasNote,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: hasNote
                ? AppTheme.champagne.withValues(alpha: 0.18)
                : const Color(0xFF132A5C).withValues(alpha: 0.85),
            border: Border.all(
              color: hasNote
                  ? AppTheme.champagne.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasNote
                    ? Icons.sticky_note_2_rounded
                    : Icons.sticky_note_2_outlined,
                size: 16,
                color: hasNote
                    ? AppTheme.champagneLight
                    : Colors.white.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 6),
              Text(
                'NOTLAR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: hasNote
                      ? AppTheme.champagneLight
                      : Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Neon bilgi kartı yüzü.
class LessonCardFace extends StatelessWidget {
  final TopicLessonModel lesson;
  final int index;
  final int total;
  final bool showCounter;
  final bool showHeart;
  final ValueChanged<bool>? onScrollLockChanged;
  final ScrollController? scrollController;
  final List<QuizStroke>? strokes;
  final bool drawingEnabled;
  final Color? penColor;
  final double? penWidth;
  final bool highlighter;
  final ValueChanged<QuizStroke>? onStrokeComplete;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;
  final VoidCallback? onNotesTap;

  const LessonCardFace({
    super.key,
    required this.lesson,
    required this.index,
    required this.total,
    this.showCounter = true,
    this.showHeart = true,
    this.onScrollLockChanged,
    this.scrollController,
    this.strokes,
    this.drawingEnabled = false,
    this.penColor,
    this.penWidth,
    this.highlighter = false,
    this.onStrokeComplete,
    this.onUndo,
    this.onClear,
    this.onNotesTap,
  });

  /// Favorilerden tam kart göstermek için.
  static Future<void> showViewer(
    BuildContext context,
    TopicLessonModel lesson, {
    int index = 1,
    int total = 1,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.62,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              LessonCardFace(
                lesson: lesson,
                index: index,
                total: total,
              ),
              Positioned(
                top: -6,
                right: -6,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(ctx).pop(),
                    customBorder: const CircleBorder(),
                    child: Ink(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A2438).withValues(alpha: 0.95),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = strokes ?? const <QuizStroke>[];
    final scrollOffset =
        scrollController?.hasClients == true ? scrollController!.offset : 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neonEdge.withValues(alpha: 0.22),
            blurRadius: 22,
          ),
          BoxShadow(
            color: AppTheme.neonGold.withValues(alpha: 0.14),
            blurRadius: 28,
            spreadRadius: -2,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF141E32),
                      Color(0xFF0C1424),
                      Color(0xFF090F1A),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -36,
              top: -44,
              child: IgnorePointer(
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.neonEdge.withValues(alpha: 0.18),
                        AppTheme.neonEdge.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -44,
              bottom: -52,
              child: IgnorePointer(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.neonGold.withValues(alpha: 0.14),
                        AppTheme.neonGold.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  width: 1.35,
                  color: AppTheme.neonEdge.withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: showCounter
                              ? Container(
                                  padding: const EdgeInsets.fromLTRB(
                                      10, 5, 10, 5),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: AppTheme.inkSoft
                                        .withValues(alpha: 0.92),
                                    border: Border.all(
                                      color: AppTheme.neonEdge
                                          .withValues(alpha: 0.65),
                                    ),
                                  ),
                                  child: Text(
                                    '$index / $total',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.7,
                                      color: AppTheme.neonEdge
                                          .withValues(alpha: 0.95),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      if (onNotesTap != null)
                        ListenableBuilder(
                          listenable: LessonCardNotesService.instance,
                          builder: (context, _) {
                            final hasNote = LessonCardNotesService.instance
                                .hasNote(lesson.id);
                            return _NotesChip(
                              hasNote: hasNote,
                              onTap: onNotesTap,
                            );
                          },
                        ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: showHeart
                              ? ListenableBuilder(
                                  listenable:
                                      LessonCardProgressService.instance,
                                  builder: (context, _) {
                                    final fav = LessonCardProgressService
                                        .instance
                                        .isFavorite(lesson.id);
                                    return Container(
                                      width: 38,
                                      height: 38,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white
                                            .withValues(alpha: 0.06),
                                        border: Border.all(
                                          color: fav
                                              ? const Color(0xFFF87171)
                                                  .withValues(alpha: 0.55)
                                              : Colors.white
                                                  .withValues(alpha: 0.14),
                                        ),
                                      ),
                                      child: FavoriteHeartButton(
                                        isFavorite: fav,
                                        onToggle: () async {
                                          await LessonCardProgressService
                                              .instance
                                              .toggleFavorite(lesson.id);
                                        },
                                      ),
                                    );
                                  },
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                  if (showCounter) ...[
                    const SizedBox(height: 12),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.neonEdge.withValues(alpha: 0.7),
                            AppTheme.neonGold.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      lesson.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (lesson.imageUrl != null &&
                      lesson.imageUrl!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          lesson.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (onScrollLockChanged == null) return false;
                            if (n is ScrollStartNotification) {
                              onScrollLockChanged!(true);
                            } else if (n is ScrollEndNotification) {
                              onScrollLockChanged!(false);
                            }
                            return false;
                          },
                          child: SingleChildScrollView(
                            controller: scrollController,
                            physics: drawingEnabled
                                ? const NeverScrollableScrollPhysics()
                                : const ClampingScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                            padding:
                                const EdgeInsets.only(right: 4, bottom: 4),
                            child: FormattedText(
                              lesson.body,
                              preserveLineBreaks: true,
                              examWrap: true,
                              examScaleDown: false,
                              style: TextStyle(
                                fontSize: 15.5,
                                height: 1.55,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ),
                        if (!drawingEnabled && ink.isNotEmpty)
                          QuizStrokeLayer(strokes: ink),
                        if (drawingEnabled &&
                            onStrokeComplete != null &&
                            onClear != null)
                          QuizDrawingOverlay(
                            showToolbar: false,
                            penColor: penColor,
                            penWidth: penWidth,
                            highlighter: highlighter,
                            scrollOffset: scrollOffset,
                            contentPadding:
                                const EdgeInsets.only(right: 4, bottom: 4),
                            strokes: ink,
                            onStrokeComplete: onStrokeComplete!,
                            onUndo: onUndo,
                            onClear: onClear!,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool busy;
  final bool drawingHint;
  final VoidCallback onForgot;
  final VoidCallback onKnow;

  const _ActionBar({
    required this.busy,
    required this.onForgot,
    required this.onKnow,
    this.drawingHint = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF243048).withValues(alpha: 0.95),
                const Color(0xFF162033).withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(
              color: AppTheme.neonEdge.withValues(alpha: 0.35),
              width: 1.1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onForgot,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF87171),
                    side: BorderSide(
                      color: const Color(0xFFF87171).withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Unuttum'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onKnow,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.champagne,
                    foregroundColor: AppTheme.ink,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Biliyorum'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          drawingHint
              ? 'Kalem açıkken kaydırma kapalı · kalemi kapatınca devam'
              : 'Sola kaydır: Unuttum · Sağa kaydır: Biliyorum',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  final int total;
  const _EmptyDeck({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        total == 0
            ? 'Bu konu için henüz bilgi kartı yok.'
            : 'Tüm kartları bildin. Tekrar için Favoriler → Tekrar Et’e bakabilirsin.',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      ),
    );
  }
}

class _SwipeStamp extends StatelessWidget {
  final String label;
  final Color color;
  final Alignment alignment;
  final double opacity;

  const _SwipeStamp({
    required this.label,
    required this.color,
    required this.alignment,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: alignment == Alignment.topLeft ? -0.25 : 0.25,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color, width: 2),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AtmosphereBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _AtmosphereBlob({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
