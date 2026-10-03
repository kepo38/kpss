import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../navigation/app_navigator.dart';
import '../utils/app_version_utils.dart';
import '../widgets/app_update_dialog.dart';
import 'app_config_service.dart';

/// Panelden gelen önerilen sürüme göre Play Store güncelleme diyaloğu.
class AppUpdateService {
  AppUpdateService._();

  static const _dismissKey = 'app_update_dismissed_recommended_v1';
  static bool _launchPromptHandled = false;

  /// Açılışta bir kez dene — splash sonrası ana ekranda gösterilir.
  static Future<void> maybeShowOnLaunch() async {
    if (_launchPromptHandled) return;
    if (kIsWeb || !Platform.isAndroid) return;

    _launchPromptHandled = true;

    final config = AppConfigService.instance;
    if (!config.isLoaded) {
      await config.refresh();
    }
    if (!config.isLoaded) return;

    final recommended = config.recommendedAppVersion.trim();
    if (recommended.isEmpty) return;

    final package = await PackageInfo.fromPlatform();
    if (!isAppVersionOlder(package.version, recommended)) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_dismissKey) == recommended) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_presentDialog(recommended));
    });
  }

  static Future<void> _presentDialog(String recommended) async {
    final context = AppNavigator.key.currentContext;
    if (context == null) return;

    final openStore = await showAppUpdateDialogAndMaybeOpenStore(context);
    if (openStore) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissKey, recommended);
  }

  @visibleForTesting
  static void resetLaunchPromptForTests() {
    _launchPromptHandled = false;
  }
}
