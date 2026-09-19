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

  const QuizStrokeLayer({
    super.key,
    required this.strokes,
  });

  @override
  Widget build(BuildContext context) {
    if (strokes.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: QuizStrokePainter(
          strokes,
          paintOffset: Offset.zero,
        ),
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
  final EdgeInsets contentPadding;

  const QuizDrawingOverlay({
    super.key,
    required this.strokes,
    required this.onStrokeComplete,
    required this.onClear,
    this.onUndo,
    this.scrollOffset = 0,
    this.contentPadding = EdgeInsets.zero,
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
  static const _toolbarMinBottom = 8.0;
  static const _toolbarApproxHeight = 64.0;

  Color _color = _colors.first;
  double _width = _widths[1];
  bool _highlighter = false;
  final _points = <Offset>[];

  /// Araç çubuğunun alttan uzaklığı — sürükleyerek değişir.
  double _toolbarBottom = 12;

  Offset _toContent(Offset viewport) => Offset(
        viewport.dx - widget.contentPadding.left,
        viewport.dy - widget.contentPadding.top + widget.scrollOffset,
      );

  Offset get _paintOffset => Offset(
        -widget.contentPadding.left,
        -widget.contentPadding.top + widget.scrollOffset,
      );

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
        eraser: false,
        highlighter: _highlighter,
      ),
    );
    _points.clear();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBottom = (constraints.maxHeight - _toolbarApproxHeight)
            .clamp(_toolbarMinBottom, constraints.maxHeight);
        final bottom =
            _toolbarBottom.clamp(_toolbarMinBottom, maxBottom).toDouble();

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
                // child yok: CustomPaint Positioned.fill boyutunu alır.
                // SizedBox.expand + boş saveLayer Impeller'da beyaz örtü yapıyordu.
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: QuizStrokePainter(
                      [
                        ...widget.strokes,
                        if (_points.isNotEmpty)
                          QuizStroke(
                            points: _points,
                            color: _highlighter
                                ? _highlighterColor
                                : _color,
                            width: _highlighter
                                ? _highlighterWidth
                                : _width,
                            eraser: false,
                            highlighter: _highlighter,
                          ),
                      ],
                      paintOffset: _paintOffset,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: bottom,
              child: Material(
                color: Colors.transparent,
                elevation: 0,
                child: Container(
                  width: double.infinity,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (details) {
                          setState(() {
                            _toolbarBottom = (_toolbarBottom - details.delta.dy)
                                .clamp(_toolbarMinBottom, maxBottom)
                                .toDouble();
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Column(
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sürükle',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final color in _colors)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: _ToolButton(
                                    selected:
                                        !_highlighter && _color == color,
                                    tooltip: 'Kalem rengi',
                                    onTap: () => setState(() {
                                      _color = color;
                                      _highlighter = false;
                                    }),
                                    child: _ColorSwatch(
                                      color: color,
                                      selected:
                                          !_highlighter && _color == color,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: _ToolButton(
                                  selected: _highlighter,
                                  tooltip: 'Yeşil fosfor',
                                  highlight: true,
                                  onTap: () => setState(() {
                                    _highlighter = true;
                                  }),
                                  child: Container(
                                    width: 24,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: _highlighterColor.withValues(
                                        alpha: 0.72,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: _highlighter
                                            ? Colors.white
                                            : Colors.white
                                                .withValues(alpha: 0.7),
                                        width: _highlighter ? 2 : 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _highlighterColor.withValues(
                                            alpha: _highlighter ? 0.7 : 0.35,
                                          ),
                                          blurRadius: _highlighter ? 10 : 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const _ToolbarDivider(),
                              for (final width in _widths)
                                Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: _ToolButton(
                                    selected:
                                        !_highlighter && _width == width,
                                    tooltip: 'Kalem kalınlığı',
                                    onTap: () => setState(() {
                                      _width = width;
                                      _highlighter = false;
                                    }),
                                    child: Icon(
                                      Icons.circle,
                                      size: width + 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              const _ToolbarDivider(tall: true),
                              if (widget.onUndo != null) ...[
                                _ToolButton(
                                  selected: false,
                                  tooltip: 'Son çizimi geri al',
                                  onTap: widget.onUndo!,
                                  child: Icon(
                                    Icons.undo_rounded,
                                    size: 22,
                                    color:
                                        Colors.white.withValues(alpha: 0.98),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              _ToolButton(
                                selected: false,
                                tooltip: 'Tüm çizimi temizle',
                                onTap: widget.onClear,
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 22,
                                  color: Color(0xFFFF8A80),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;

  const _ColorSwatch({required this.color, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: selected ? 20 : 16,
      height: selected ? 20 : 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppTheme.champagneLight : Colors.white,
          width: selected ? 2.4 : 1.4,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: AppTheme.champagne.withValues(alpha: 0.45),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  final bool tall;

  const _ToolbarDivider({this.tall = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tall ? 1.2 : 1,
      height: tall ? 26 : 22,
      margin: EdgeInsets.symmetric(horizontal: tall ? 8 : 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: Colors.white.withValues(alpha: tall ? 0.32 : 0.2),
      ),
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
  final Offset paintOffset;

  const QuizStrokePainter(
    this.strokes, {
    this.paintOffset = Offset.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || strokes.isEmpty) return;

    // BlendMode.clear + saveLayer Impeller'da tüm viewport'u beyaz
    // kaplayabiliyor. Silgi yerine quiz zemin rengiyle üzerini boya.
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..blendMode = BlendMode.srcOver;

      if (stroke.eraser) {
        paint.color = AppTheme.ink;
      } else if (stroke.highlighter) {
        paint.color = stroke.color.withValues(alpha: 0.44);
      } else {
        paint.color = stroke.color;
      }

      final path = Path()
        ..moveTo(
          stroke.points.first.dx - paintOffset.dx,
          stroke.points.first.dy - paintOffset.dy,
        );
      for (final point in stroke.points.skip(1)) {
        path.lineTo(
          point.dx - paintOffset.dx,
          point.dy - paintOffset.dy,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant QuizStrokePainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.paintOffset != paintOffset;
}
