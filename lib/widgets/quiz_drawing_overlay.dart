import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class QuizStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool eraser;

  const QuizStroke({
    required this.points,
    required this.color,
    required this.width,
    this.eraser = false,
  });
}

class QuizDrawingOverlay extends StatefulWidget {
  final List<QuizStroke> strokes;
  final ValueChanged<QuizStroke> onStrokeComplete;
  final VoidCallback onClear;

  const QuizDrawingOverlay({
    super.key,
    required this.strokes,
    required this.onStrokeComplete,
    required this.onClear,
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

  Color _color = _colors.first;
  double _width = _widths[1];
  bool _eraser = false;
  final _points = <Offset>[];

  void _finishStroke() {
    if (_points.length < 2) {
      _points.clear();
      return;
    }
    widget.onStrokeComplete(
      QuizStroke(
        points: List.of(_points),
        color: _color,
        width: _width,
        eraser: _eraser,
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
                ..add(details.localPosition);
            }),
            onPanUpdate: (details) =>
                setState(() => _points.add(details.localPosition)),
            onPanEnd: (_) => setState(_finishStroke),
            child: CustomPaint(
              painter: _StrokePainter([
                ...widget.strokes,
                if (_points.isNotEmpty)
                  QuizStroke(
                    points: _points,
                    color: _color,
                    width: _width,
                    eraser: _eraser,
                  ),
              ]),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Material(
                color: Colors.transparent,
                elevation: 10,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF132A5C).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.champagne.withValues(alpha: 0.28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      for (final color in _colors)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _ToolButton(
                            selected: !_eraser && _color == color,
                            onTap: () => setState(() {
                              _color = color;
                              _eraser = false;
                            }),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  width: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      _ToolbarDivider(),
                      for (final width in _widths)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _ToolButton(
                            selected: !_eraser && _width == width,
                            onTap: () => setState(() {
                              _width = width;
                              _eraser = false;
                            }),
                            child: Icon(
                              Icons.circle,
                              size: width + 4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      _ToolbarDivider(),
                      _ToolButton(
                        selected: _eraser,
                        tooltip: 'Silgi',
                        onTap: () => setState(() => _eraser = true),
                        child: Icon(
                          Icons.auto_fix_high_rounded,
                          size: 18,
                          color: _eraser
                              ? AppTheme.champagneLight
                              : Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _ToolButton(
                        selected: false,
                        tooltip: 'Tüm çizimi temizle',
                        onTap: widget.onClear,
                        child: Icon(
                          Icons.delete_forever_rounded,
                          size: 19,
                          color: const Color(0xFFF87171).withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
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
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white.withValues(alpha: 0.18),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String? tooltip;

  const _ToolButton({
    required this.selected,
    required this.onTap,
    required this.child,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: selected
          ? AppTheme.champagne.withValues(alpha: 0.22)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(child: child),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _StrokePainter extends CustomPainter {
  final List<QuizStroke> strokes;

  const _StrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = stroke.eraser ? BlendMode.clear : BlendMode.srcOver;
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}
