import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Yanlış defterinden silince ortada kısa süreli premium kutu.
class WrongNotebookRemoveToast {
  WrongNotebookRemoveToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(BuildContext context, {required String preview}) {
    hide();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _entry = OverlayEntry(
      builder: (ctx) {
        return IgnorePointer(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.18),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 340),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1C2A42),
                          AppTheme.inkSoft,
                          AppTheme.ink,
                        ],
                      ),
                      border: Border.all(
                        color: AppTheme.champagne,
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.champagne.withValues(alpha: 0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.champagne.withValues(alpha: 0.16),
                            border: Border.all(
                              color: AppTheme.champagne.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: AppTheme.champagneLight,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Defterden kaldırıldı',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '«$preview»',
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
    _timer = Timer(const Duration(seconds: 3), hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}
