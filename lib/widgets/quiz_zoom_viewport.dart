import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soru / çözüm içeriği için pinch-to-zoom + çift dokunuş.
///
/// Çizim modu açıkken [zoomEnabled]=false → pan/zoom kilitlenir ve matris
/// sıfırlanır; kalem kapatılınca InteractiveViewer yeniden aktif olur.
class QuizZoomViewport extends StatefulWidget {
  final Widget child;
  final bool zoomEnabled;
  final TransformationController? controller;
  final double minScale;
  final double maxScale;
  final EdgeInsets boundaryMargin;

  const QuizZoomViewport({
    super.key,
    required this.child,
    this.zoomEnabled = true,
    this.controller,
    this.minScale = 1,
    this.maxScale = 4,
    this.boundaryMargin = const EdgeInsets.fromLTRB(48, 72, 48, 120),
  });

  @override
  State<QuizZoomViewport> createState() => _QuizZoomViewportState();
}

class _QuizZoomViewportState extends State<QuizZoomViewport>
    with SingleTickerProviderStateMixin {
  late final TransformationController _controller;
  late final bool _ownsController;
  AnimationController? _anim;
  Animation<Matrix4>? _matrixAnim;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TransformationController();
    _controller.addListener(_onTransform);
  }

  @override
  void didUpdateWidget(covariant QuizZoomViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.zoomEnabled && oldWidget.zoomEnabled) {
      _resetImmediate();
    }
  }

  void _onTransform() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _anim?.dispose();
    _controller.removeListener(_onTransform);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  bool get _isZoomed {
    final s = _controller.value.getMaxScaleOnAxis();
    return s > 1.02;
  }

  void _resetImmediate() {
    _anim?.stop();
    _controller.value = Matrix4.identity();
  }

  void _animateTo(Matrix4 target) {
    _anim?.dispose();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    final begin = Matrix4.copy(_controller.value);
    _matrixAnim = Matrix4Tween(begin: begin, end: target).animate(
      CurvedAnimation(parent: _anim!, curve: Curves.easeOutCubic),
    );
    void tick() => _controller.value = _matrixAnim!.value;
    _matrixAnim!.addListener(tick);
    _anim!.forward().whenComplete(() {
      _matrixAnim?.removeListener(tick);
    });
  }

  void _handleDoubleTap() {
    if (!widget.zoomEnabled) return;
    final details = _doubleTapDetails;
    if (_isZoomed) {
      _animateTo(Matrix4.identity());
      return;
    }
    final focal = details?.localPosition ?? Offset.zero;
    const zoom = 2.2;
    final matrix = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(zoom, zoom, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
    _animateTo(matrix);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onDoubleTapDown: widget.zoomEnabled
                  ? (d) => _doubleTapDetails = d
                  : null,
              onDoubleTap: widget.zoomEnabled ? _handleDoubleTap : null,
              child: InteractiveViewer(
                transformationController: _controller,
                constrained: false,
                clipBehavior: Clip.hardEdge,
                alignment: Alignment.topCenter,
                boundaryMargin: widget.boundaryMargin,
                minScale: widget.minScale,
                maxScale: widget.maxScale,
                panEnabled: widget.zoomEnabled,
                scaleEnabled: widget.zoomEnabled,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: widget.child,
                ),
              ),
            ),
            if (widget.zoomEnabled && _isZoomed)
              Positioned(
                right: 12,
                bottom: 12,
                child: Material(
                  color: const Color(0xFF132A5C).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(999),
                  elevation: 6,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _animateTo(Matrix4.identity()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.zoom_out_map_rounded,
                            size: 18,
                            color: AppTheme.champagneLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sıfırla',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.champagneLight,
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
      },
    );
  }
}
