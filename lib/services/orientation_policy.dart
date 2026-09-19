import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Uygulama her cihazda yalnızca dikey (portrait) mod.
class OrientationPolicy {
  OrientationPolicy._();

  static Future<void> apply() async {
    if (kIsWeb) return;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}
