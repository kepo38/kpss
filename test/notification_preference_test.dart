import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/services/notification_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await NotificationPreferenceService.instance.initialize();
  });

  test('varsayılan kullanıcı türleri açık', () {
    final prefs = NotificationPreferenceService.instance;
    expect(prefs.allEnabled, isTrue);
    for (final meta in NotificationPreferenceService.kinds) {
      expect(prefs.isEnabled(meta.kind), isTrue);
    }
  });

  test('tek tür kapatılınca diğerleri açık kalır', () async {
    final prefs = NotificationPreferenceService.instance;
    await prefs.setEnabled(NotificationKind.eveningFomo, false);

    expect(prefs.isEnabled(NotificationKind.eveningFomo), isFalse);
    expect(prefs.isEnabled(NotificationKind.morningMotivation), isTrue);
    expect(prefs.allEnabled, isFalse);
  });

  test('tümünü kapat duyuru ve kazancı kapatmaz', () async {
    final prefs = NotificationPreferenceService.instance;
    await prefs.setAll(false);
    expect(prefs.allEnabled, isFalse);
    expect(prefs.isEnabled(NotificationKind.morningMotivation), isFalse);
    expect(prefs.isEnabled(NotificationKind.eveningFomo), isFalse);
    expect(prefs.isEnabled(NotificationKind.weeklySummary), isFalse);
    expect(prefs.isEnabled(NotificationKind.announcements), isTrue);
    expect(prefs.isEnabled(NotificationKind.savingsMilestone), isTrue);

    await prefs.setAll(true);
    expect(prefs.allEnabled, isTrue);
  });

  test('kayıtlı kapalı duyuru yine de açıktır', () async {
    SharedPreferences.setMockInitialValues({
      'notif_pref_v1_announcements': false,
      'notif_pref_v1_savingsMilestone': false,
      'notif_pref_v1_weeklySummary': false,
    });
    await NotificationPreferenceService.instance.initialize();
    final prefs = NotificationPreferenceService.instance;

    expect(prefs.isEnabled(NotificationKind.announcements), isTrue);
    expect(prefs.isEnabled(NotificationKind.savingsMilestone), isTrue);
    expect(prefs.isEnabled(NotificationKind.weeklySummary), isFalse);
  });

  test('kilitli tür setEnabled ile kapanmaz', () async {
    final prefs = NotificationPreferenceService.instance;
    await prefs.setEnabled(NotificationKind.announcements, false);
    await prefs.setEnabled(NotificationKind.savingsMilestone, false);
    expect(prefs.isEnabled(NotificationKind.announcements), isTrue);
    expect(prefs.isEnabled(NotificationKind.savingsMilestone), isTrue);
  });
}
