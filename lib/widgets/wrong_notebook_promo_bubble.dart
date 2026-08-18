import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/wrong_questions_screen.dart';
import '../services/ad_manager.dart';
import '../services/app_config_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Ana sayfa sağ kenarı — sürüklenebilir metin balonu → yanlış defteri.
class WrongNotebookPromoBubble extends StatefulWidget {
  const WrongNotebookPromoBubble({super.key});

  @override
  State<WrongNotebookPromoBubble> createState() =>
      _WrongNotebookPromoBubbleState();
}

class _WrongNotebookPromoBubbleState extends State<WrongNotebookPromoBubble> {
  static const _kYRatio = 'wrong_notebook_bubble_y_ratio';

  final GlobalKey _balloonKey = GlobalKey();
  double _yRatio = 0.58;
  bool _ratioLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRatio());
  }

  Future<void> _loadRatio() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kYRatio);
    if (!mounted) return;
    setState(() {
      if (saved != null) _yRatio = saved.clamp(0.08, 0.92);
      _ratioLoaded = true;
    });
  }

  Future<void> _saveRatio(double ratio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kYRatio, ratio.clamp(0.08, 0.92));
  }

  Future<void> _openWrongNotebook(BuildContext context) async {
    await AdManager.instance.onPageTransition();
    if (!context.mounted) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const WrongQuestionsScreen(),
        ),
      ),
    );
  }

  ({double minY, double maxY, double y}) _verticalBounds(
    BuildContext context,
    double bubbleHeight,
  ) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    const topBar = 52.0;
    const bottomBar = 92.0;
    final minY = pad.top + topBar;
    final maxY = math.max(minY, size.height - pad.bottom - bottomBar - bubbleHeight);
    final y = minY + (maxY - minY) * _yRatio;
    return (minY: minY, maxY: maxY, y: y.clamp(minY, maxY));
  }

  void _onDragUpdate(BuildContext context, double deltaDy) {
    final box = _balloonKey.currentContext?.findRenderObject() as RenderBox?;
    final bubbleH = box?.size.height ?? 96;
    final bounds = _verticalBounds(context, bubbleH);
    final span = bounds.maxY - bounds.minY;
    if (span <= 0) return;
    setState(() {
      final currentY = bounds.minY + span * _yRatio;
      final nextY = (currentY + deltaDy).clamp(bounds.minY, bounds.maxY);
      _yRatio = ((nextY - bounds.minY) / span).clamp(0.08, 0.92);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppConfigService.instance,
        AuthService.instance,
      ]),
      builder: (context, _) {
        final cfg = AppConfigService.instance;
        if (!cfg.showWrongNotebookBubble || !_ratioLoaded) {
          return const SizedBox.shrink();
        }

        const bubbleHeightEstimate = 96.0;
        final bounds = _verticalBounds(context, bubbleHeightEstimate);

        return Positioned(
          right: 0,
          top: bounds.y,
          child: _PromoBalloon(
            key: _balloonKey,
            onDismiss: AppConfigService.instance.dismissWrongNotebookBubble,
            onOpen: () => _openWrongNotebook(context),
            onDragUpdate: (dy) => _onDragUpdate(context, dy),
            onDragEnd: () => unawaited(_saveRatio(_yRatio)),
          ),
        );
      },
    );
  }
}

class _PromoBalloon extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onOpen;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;

  const _PromoBalloon({
    super.key,
    required this.onDismiss,
    required this.onOpen,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink;

    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) => onDragUpdate(d.delta.dy),
            onVerticalDragEnd: (_) => onDragEnd(),
            onTap: onOpen,
            child: Container(
              width: 52,
              padding: const EdgeInsets.fromLTRB(10, 16, 6, 16),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF8EE),
                    Color(0xFFF0E0BC),
                    Color(0xFFE8CF98),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFD4AF6A).withValues(alpha: 0.85),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.champagne.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(-2, 4),
                  ),
                  BoxShadow(
                    color: AppTheme.ink.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'YANLIŞ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.05,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w900,
                      color: ink.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'DEFTERİ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.05,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w900,
                      color: ink.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 2,
            left: 2,
            child: GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '×',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: ink.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
