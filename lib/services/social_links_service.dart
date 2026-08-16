import 'package:url_launcher/url_launcher.dart';

/// Sosyal medya ve dış bağlantılar.
class SocialLinksService {
  SocialLinksService._();

  static const instagramUsername = 'hedefkamu.app';

  static Future<void> openInstagramProfile() async {
    final appUri = Uri.parse('instagram://user?username=$instagramUsername');
    final profileUri = Uri.parse('https://www.instagram.com/$instagramUsername/');

    if (await canLaunchUrl(appUri)) {
      final opened = await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    }

    await launchUrl(profileUri, mode: LaunchMode.externalApplication);
  }
}
