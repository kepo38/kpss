import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Tabletlerde yalnızca dikey (portrait) mod.
class OrientationPolicy {
  OrientationPolicy._();

  /// Material / Flutter tablet eşiği (dp).
  static const double tabletBreakpoint = 600;

  static bool get isTablet {
    if (kIsWeb) return false;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return false;
    final view = views.first;
    final logical = view.physicalSize / view.devicePixelRatio;
    return logical.shortestSide >= tabletBreakpoint;
  }

  static Future<void> apply() async {
    if (kIsWeb) return;
    if (isTablet) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }
}
