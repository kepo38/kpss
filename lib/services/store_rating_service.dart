import 'package:url_launcher/url_launcher.dart';

/// Play Store değerlendirme sayfasını açar.
class StoreRatingService {
  StoreRatingService._();

  static const _packageId = 'com.example.kpss_odak';

  static Future<void> openStoreListing() async {
    final market = Uri.parse('market://details?id=$_packageId');
    final web = Uri.parse(
      'https://play.google.com/store/apps/details?id=$_packageId',
    );

    if (await canLaunchUrl(market)) {
      await launchUrl(market, mode: LaunchMode.externalApplication);
      return;
    }
    if (await canLaunchUrl(web)) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }
}
