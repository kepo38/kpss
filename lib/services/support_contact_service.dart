import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/brand_constants.dart';
import 'auth_service.dart';
import 'premium_service.dart';

/// Destek e-postası ve iletişim bağlantıları.
class SupportContactService {
  SupportContactService._();

  static const supportEmail = 'hedefkamu@gmail.com';

  static Future<bool> openSupportEmail() async {
    final body = await buildSupportEmailBody();
    final subject = '${BrandConstants.appName} Destek Talebi';
    // queryParameters ile encode; canLaunchUrl Android 11'de mailto için
    // sık false döner — doğrudan launch dene.
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return true;
    } catch (_) {
      // aşağıda platformDefault dene
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }

  /// Gmail / e-posta uygulamasına düşecek taslak metin.
  @visibleForTesting
  static Future<String> buildSupportEmailBody() async {
    final snapshot = await collectSupportDeviceSnapshot();
    return '''Uygulama Bilgileri:

- Sürüm: ${snapshot.version}
- Cihaz: ${snapshot.device}
- ${snapshot.platformLabel}: ${snapshot.platformVersion}
- Üyelik: ${snapshot.membership}

Merhaba,
''';
  }

  @visibleForTesting
  static Future<SupportDeviceSnapshot> collectSupportDeviceSnapshot() async {
    final package = await PackageInfo.fromPlatform();
    final version = package.version;

    var device = 'Bilinmiyor';
    var platformLabel = 'Platform';
    var platformVersion = 'Bilinmiyor';

    if (kIsWeb) {
      platformLabel = 'Web';
      platformVersion = defaultTargetPlatform.name;
      device = 'Tarayıcı';
    } else {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        device = android.model.trim().isNotEmpty
            ? android.model
            : '${android.manufacturer} ${android.device}';
        platformLabel = 'Android';
        platformVersion = android.version.release;
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        device = ios.utsname.machine;
        platformLabel = 'iOS';
        platformVersion = ios.systemVersion;
      } else {
        platformLabel = Platform.operatingSystem;
        platformVersion = Platform.operatingSystemVersion;
      }
    }

    return SupportDeviceSnapshot(
      version: version,
      device: device,
      platformLabel: platformLabel,
      platformVersion: platformVersion,
      membership: _membershipLabel(),
    );
  }

  static String _membershipLabel() {
    if (PremiumService.instance.isPremium) return 'Premium';
    final user = AuthService.instance.user;
    if (user == null ||
        user.isAnonymous ||
        AuthService.instance.isLocalGuest) {
      return 'Misafir';
    }
    return 'Standart';
  }

}

@visibleForTesting
class SupportDeviceSnapshot {
  final String version;
  final String device;
  final String platformLabel;
  final String platformVersion;
  final String membership;

  const SupportDeviceSnapshot({
    required this.version,
    required this.device,
    required this.platformLabel,
    required this.platformVersion,
    required this.membership,
  });
}
