import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class QuizStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool eraser;
  final bool highlighter;

  const QuizStroke({
    required this.points,
    required this.color,
    required this.width,
    this.eraser = false,
    this.highlighter = false,
  });
}

/// Kaydedilmiş çizimleri etkileşimsiz gösterir (kalem kapalıyken).
class QuizStrokeLayer extends StatelessWidget {
  final List<QuizStroke> strokes;
  final double scrollOffset;

  const QuizStrokeLayer({
    super.key,
    required this.strokes,
    this.scrollOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (strokes.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: QuizStrokePainter(strokes, scrollOffset: scrollOffset),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class QuizDrawingOverlay extends StatefulWidget {
  final List<QuizStroke> strokes;
  final ValueChanged<QuizStroke> onStrokeComplete;
  final VoidCallback onClear;
  final VoidCallback? onUndo;
  final double scrollOffset;

  const QuizDrawingOverlay({
    super.key,
    required this.strokes,
    required this.onStrokeComplete,
    required this.onClear,
    this.onUndo,
    this.scrollOffset = 0,
  });

  @override
  State<QuizDrawingOverlay> createState() => _QuizDrawingOverlayState();
}

class _QuizDrawingOverlayState extends State<QuizDrawingOverlay> {
  static const _colors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Colors.black,
  ];
  static const _widths = [2.5, 4.5, 7.5];
  static const _highlighterColor = Color(0xFFCCFF00);
  static const _highlighterWidth = 28.0;
  static const _maxPointsPerStroke = 400;
  static const _minPointDelta = 2.0;

  Color _color = _colors.first;
  double _width = _widths[1];
  bool _eraser = false;
  bool _highlighter = false;
  final _points = <Offset>[];

  Offset _toContent(Offset viewport) =>
      Offset(viewport.dx, viewport.dy + widget.scrollOffset);

  void _addPoint(Offset viewportPoint) {
    final point = _toContent(viewportPoint);
    if (_points.isEmpty) {
      _points.add(point);
      return;
    }
    if (_points.length >= _maxPointsPerStroke) return;
    if ((point - _points.last).distance < _minPointDelta) return;
    _points.add(point);
  }

  void _finishStroke() {
    if (_points.length < 2) {
      _points.clear();
      return;
    }
    widget.onStrokeComplete(
      QuizStroke(
        points: List.of(_points),
        color: _highlighter ? _highlighterColor : _color,
        width: _highlighter ? _highlighterWidth : _width,
        eraser: _eraser,
        highlighter: _highlighter && !_eraser,
      ),
    );
    _points.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => setState(() {
              _points
                ..clear()
                ..add(_toContent(details.localPosition));
            }),
            onPanUpdate: (details) {
              final before = _points.length;
              _addPoint(details.localPosition);
              if (_points.length != before) setState(() {});
            },
            onPanEnd: (_) => setState(_finishStroke),
            child: CustomPaint(
              painter: QuizStrokePainter(
                [
                  ...widget.strokes,
                  if (_points.isNotEmpty)
                    QuizStroke(
                      points: _points,
                      color: _highlighter ? _highlighterColor : _color,
                      width: _highlighter ? _highlighterWidth : _width,
                      eraser: _eraser,
                      highlighter: _highlighter && !_eraser,
                    ),
                ],
                scrollOffset: widget.scrollOffset,
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Material(
            color: Colors.transparent,
            elevation: 10,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF132A5C).withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.champagne.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                  for (final color in _colors)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _ToolButton(
                        selected: !_eraser && !_highlighter && _color == color,
                        onTap: () => setState(() {
                          _color = color;
                          _eraser = false;
                          _highlighter = false;
                        }),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _ToolButton(
                      selected: _highlighter && !_eraser,
                      tooltip: 'Yeşil fosfor',
                      highlight: true,
                      onTap: () => setState(() {
                        _highlighter = true;
                        _eraser = false;
                      }),
                      child: Container(
                        width: 24,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _highlighterColor.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _highlighterColor.withValues(alpha: 0.45),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _ToolbarDivider(),
                  for (final width in _widths)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: _ToolButton(
                        selected: !_eraser && !_highlighter && _width == width,
                        onTap: () => setState(() {
                          _width = width;
                          _eraser = false;
                          _highlighter = false;
                        }),
                        child: Icon(
                          Icons.circle,
                          size: width + 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  _ToolbarDivider(),
                  _ToolButton(
                    selected: _eraser,
                    tooltip: 'Silgi',
                    onTap: () => setState(() {
                      _eraser = true;
                      _highlighter = false;
                    }),
                    child: Icon(
                      Icons.backspace_rounded,
                      size: 22,
                      color: _eraser
                          ? AppTheme.champagneLight
                          : Colors.white.withValues(alpha: 0.98),
                    ),
                  ),
                  if (widget.onUndo != null) ...[
                    const SizedBox(width: 4),
                    _ToolButton(
                      selected: false,
                      tooltip: 'Son çizimi geri al',
                      onTap: widget.onUndo!,
                      child: Icon(
                        Icons.undo_rounded,
                        size: 22,
                        color: Colors.white.withValues(alpha: 0.98),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  _ToolButton(
                    selected: false,
                    tooltip: 'Tüm çizimi temizle',
                    onTap: widget.onClear,
                    child: Icon(
                      Icons.delete_sweep_rounded,
                      size: 22,
                      color: const Color(0xFFFF8A80),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ],
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.22),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String? tooltip;
  final bool highlight;

  const _ToolButton({
    required this.selected,
    required this.onTap,
    required this.child,
    this.tooltip,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: selected
          ? (highlight
              ? const Color(0xFFCCFF00).withValues(alpha: 0.28)
              : AppTheme.champagne.withValues(alpha: 0.28))
          : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: highlight
                        ? const Color(0xFFCCFF00).withValues(alpha: 0.85)
                        : AppTheme.champagneLight.withValues(alpha: 0.75),
                    width: 1.4,
                  ),
                )
              : null,
          child: child,
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class QuizStrokePainter extends CustomPainter {
  final List<QuizStroke> strokes;
  final double scrollOffset;

  const QuizStrokePainter(
    this.strokes, {
    this.scrollOffset = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.eraser) {
        paint
          ..color = stroke.color
          ..blendMode = BlendMode.clear;
      } else if (stroke.highlighter) {
        paint
          ..color = stroke.color.withValues(alpha: 0.44)
          ..blendMode = BlendMode.srcOver;
      } else {
        paint
          ..color = stroke.color
          ..blendMode = BlendMode.srcOver;
      }

      final path = Path()
        ..moveTo(
          stroke.points.first.dx,
          stroke.points.first.dy - scrollOffset,
        );
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy - scrollOffset);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant QuizStrokePainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.scrollOffset != scrollOffset;
}
