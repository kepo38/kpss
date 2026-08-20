import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/manual_question_model.dart';
import '../../services/manual_question_service.dart';
import '../../theme/app_theme.dart';
import '../manual_annotation_codec.dart';
import '../premium_gate.dart';
import '../quiz_drawing_overlay.dart';

/// Kitaptaki yanlış foto — tam ekran; premium kalem ile kalıcı çizim.
class ManualQuestionAnnotateViewer extends StatefulWidget {
  final ManualQuestionModel item;

  const ManualQuestionAnnotateViewer({super.key, required this.item});

  static Future<void> open(BuildContext context, ManualQuestionModel item) {
    return showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) => ManualQuestionAnnotateViewer(item: item),
    );
  }

  @override
  State<ManualQuestionAnnotateViewer> createState() =>
      _ManualQuestionAnnotateViewerState();
}

class _ManualQuestionAnnotateViewerState
    extends State<ManualQuestionAnnotateViewer> {
  final _strokes = <QuizStroke>[];
  bool _drawing = false;
  bool _saving = false;
  Size? _canvasSize;
  Size? _imagePixelSize;
  late ManualQuestionModel _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    unawaited(_resolveImageSize());
  }

  Future<void> _resolveImageSize() async {
    final file = File(_item.imagePath);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    final completer = Completer<Size>();
    decodeImageFromList(bytes).then((img) {
      if (!completer.isCompleted) {
        completer.complete(
          Size(img.width.toDouble(), img.height.toDouble()),
        );
      }
    }).catchError((_) {
      if (!completer.isCompleted) {
        completer.complete(const Size(1, 1));
      }
    });
    final size = await completer.future;
    if (!mounted) return;
    setState(() => _imagePixelSize = size);
  }

  void _ensureStrokes(Size size) {
    if (_canvasSize == size) return;
    _canvasSize = size;
    _strokes
      ..clear()
      ..addAll(ManualAnnotationCodec.decode(_item.annotationJson, size));
  }

  Future<void> _persist() async {
    final size = _canvasSize;
    if (size == null || _saving) return;
    setState(() => _saving = true);
    final json = _strokes.isEmpty
        ? null
        : ManualAnnotationCodec.encode(_strokes, size);
    await ManualQuestionService.instance.updateAnnotations(
      id: _item.id,
      annotationJson: json,
    );
    ManualQuestionModel? refreshed;
    for (final e in ManualQuestionService.instance.items) {
      if (e.id == _item.id) {
        refreshed = e;
        break;
      }
    }
    if (mounted) {
      setState(() {
        if (refreshed != null) _item = refreshed;
        _saving = false;
      });
    }
  }

  Future<void> _toggleDrawing() async {
    if (_drawing) {
      setState(() => _drawing = false);
      await _persist();
      return;
    }
    final ok = await PremiumGate.requirePremium(context);
    if (!ok || !mounted) return;
    setState(() => _drawing = true);
  }

  void _onStrokeComplete(QuizStroke stroke) {
    setState(() => _strokes.add(stroke));
    unawaited(_persist());
  }

  void _onUndo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
    unawaited(_persist());
  }

  void _onClear() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.clear());
    unawaited(_persist());
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = _imagePixelSize;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageSize == null)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.champagne),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final fitted = _fitSize(
                  imageSize,
                  Size(constraints.maxWidth, constraints.maxHeight),
                );
                _ensureStrokes(fitted);
                final photo = SizedBox(
                  width: fitted.width,
                  height: fitted.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(_item.imagePath),
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.high,
                      ),
                      if (!_drawing)
                        QuizStrokeLayer(strokes: List.of(_strokes)),
                      if (_drawing)
                        QuizDrawingOverlay(
                          strokes: List.of(_strokes),
                          onStrokeComplete: _onStrokeComplete,
                          onClear: _onClear,
                          onUndo: _onUndo,
                        ),
                    ],
                  ),
                );

                if (_drawing) {
                  return ColoredBox(
                    color: Colors.black,
                    child: Center(child: photo),
                  );
                }

                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Center(child: photo),
                  ),
                );
              },
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      if (_drawing) await _persist();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  if (_saving)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.champagneLight,
                        ),
                      ),
                    ),
                  _PremiumPencilButton(
                    active: _drawing,
                    onPressed: _toggleDrawing,
                  ),
                ],
              ),
            ),
          ),
          if (_drawing)
            Positioned(
              left: 0,
              right: 0,
              top: MediaQuery.paddingOf(context).top + 56,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppTheme.champagne.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    'Kalem açık · çizimler kaydedilir',
                    style: TextStyle(
                      color: AppTheme.champagneLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Size _fitSize(Size image, Size bounds) {
    if (image.width <= 0 || image.height <= 0) return bounds;
    final sx = bounds.width / image.width;
    final sy = bounds.height / image.height;
    final s = sx < sy ? sx : sy;
    return Size(image.width * s, image.height * s);
  }
}

class _PremiumPencilButton extends StatelessWidget {
  final bool active;
  final VoidCallback onPressed;

  const _PremiumPencilButton({
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: active ? 'Kalemi kapat' : 'Premium kalem',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: active
                    ? const [
                        Color(0xFFFFF8EE),
                        AppTheme.champagne,
                      ]
                    : const [
                        Color(0xFFFFF8EE),
                        Color(0xFFF3E2B8),
                        Color(0xFFE8C878),
                      ],
              ),
              border: Border.all(
                color: const Color(0xFFD4AF6A),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.champagne.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              active ? Icons.edit_off_rounded : Icons.edit_rounded,
              color: AppTheme.ink,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
