import 'package:url_launcher/url_launcher.dart';

import '../constants/brand_constants.dart';

/// Destek e-postası ve iletişim bağlantıları.
class SupportContactService {
  SupportContactService._();

  static const supportEmail = 'hedefkamu@gmail.com';

  static Future<bool> openSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: _encodeQuery({
        'subject': '${BrandConstants.appName} — Destek',
      }),
    );

    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static String? _encodeQuery(Map<String, String> params) {
    if (params.isEmpty) return null;
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }
}
