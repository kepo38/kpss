/// Django içerik API tabanı.
///
/// Emülatör → `http://10.0.2.2:8000`
/// Fiziksel cihaz → PC LAN IP (aşağıdaki varsayılan)
/// Özel: `--dart-define=KPSS_API_BASE=http://192.168.x.x:8000`
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'KPSS_API_BASE',
    defaultValue: 'http://192.168.1.109:8000',
  );

  static const String packPath = '/api/v1/pack/';
  static const String packVersionPath = '/api/v1/pack/version/';
  static const String catalogPath = '/api/v1/catalog/';
  static const String questionsPath = '/api/v1/questions/';
  static const String healthPath = '/api/v1/health/';
  static const String deviceTokensPath = '/api/v1/device-tokens/';
  static const String announcementsPath = '/api/v1/announcements/';
  static const String authGooglePath = '/api/v1/auth/google/';
  static const String mePath = '/api/v1/me/';
  static const String meMessagesPath = '/api/v1/me/messages/';
  static const String dailyMiniExamPath = '/api/v1/daily-mini-exam/';
  static const String promoRedeemPath = '/api/v1/promo/redeem/';

  static Uri packUri() => Uri.parse('$baseUrl$packPath');
  static Uri packVersionUri() => Uri.parse('$baseUrl$packVersionPath');
  static Uri catalogUri() => Uri.parse('$baseUrl$catalogPath');
  static Uri questionsByIdsUri(Iterable<String> ids) => Uri.parse(
        '$baseUrl$questionsPath',
      ).replace(queryParameters: {'ids': ids.join(',')});
  static Uri testQuestionsUri(String testId) =>
      Uri.parse('$baseUrl/api/v1/tests/${Uri.encodeComponent(testId)}/questions/');
  static Uri healthUri() => Uri.parse('$baseUrl$healthPath');
  static Uri deviceTokensUri() => Uri.parse('$baseUrl$deviceTokensPath');
  static Uri announcementsUri() => Uri.parse('$baseUrl$announcementsPath');
  static Uri authGoogleUri() => Uri.parse('$baseUrl$authGooglePath');
  static Uri meUri() => Uri.parse('$baseUrl$mePath');
  static Uri meMessagesUri() => Uri.parse('$baseUrl$meMessagesPath');
  static Uri dailyMiniExamUri(String kpssType) => Uri.parse(
        '$baseUrl$dailyMiniExamPath',
      ).replace(queryParameters: {'kpss_type': kpssType});
  static Uri promoRedeemUri() => Uri.parse('$baseUrl$promoRedeemPath');
  static Uri examTypesUri() => Uri.parse('$baseUrl/api/v1/exam-types/');
  static Uri questionRatingUri(String questionId) => Uri.parse(
        '$baseUrl/api/v1/questions/${Uri.encodeComponent(questionId)}/rating/',
      );
}
