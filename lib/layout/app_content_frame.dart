import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_breakpoints.dart';

/// MaterialApp builder — web çerçevesi + native tablet ortalama.
class AppContentFrame extends StatelessWidget {
  final Widget? child;

  const AppContentFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (child == null) return const SizedBox.shrink();

    if (kIsWeb) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      return ColoredBox(
        color: dark ? const Color(0xFF0A101C) : const Color(0xFFD8DEE8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.webFrameMaxWidth,
            ),
            child: Material(
              elevation: 12,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        ),
      );
    }

    if (AppBreakpoints.shouldFrameNativeTablet(context)) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      final maxW = AppBreakpoints.contentMaxWidth(context);
      return ColoredBox(
        color: dark ? const Color(0xFF080D16) : const Color(0xFFD0D6E0),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: child,
          ),
        ),
      );
    }

    return child!;
  }
}
