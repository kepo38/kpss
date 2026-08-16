import 'package:flutter/material.dart';

import '../services/notification_preference_service.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';

/// Profil — bildirim türlerini aç/kapa.
class NotificationSettingsSection extends StatelessWidget {
  final bool embedded;
  final bool neon;

  const NotificationSettingsSection({
    super.key,
    this.embedded = false,
    this.neon = false,
  });

  Future<void> _apply() async {
    await NotificationService.instance.applyPreferences();
    await PushNotificationService.instance.syncAnnouncementSubscription();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationPreferenceService.instance,
      builder: (context, _) {
        final prefs = NotificationPreferenceService.instance;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!embedded) ...[
              Text(
                'AYARLAR',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.champagne.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bildirimler',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                neon && embedded ? 0 : 14,
                neon && embedded ? 0 : 6,
                neon && embedded ? 0 : 8,
                neon && embedded ? 0 : 8,
              ),
              decoration: BoxDecoration(
                color: neon && embedded ? Colors.transparent : AppTheme.inkSoft,
                borderRadius: BorderRadius.circular(embedded ? 16 : 14),
                border: neon && embedded
                    ? null
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
              ),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: prefs.allEnabled,
                    activeThumbColor:
                        neon ? AppTheme.neonGold : AppTheme.champagne,
                    title: const Text(
                      'Tüm bildirimler',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      prefs.allEnabled
                          ? 'Tüm hatırlatmalar açık.'
                          : 'Kapalı. İstediğin türleri tek tek açabilirsin.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    onChanged: (value) async {
                      await prefs.setAll(value);
                      await _apply();
                    },
                  ),
                  Divider(
                    height: 18,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  for (final meta in NotificationPreferenceService.kinds)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: prefs.isEnabled(meta.kind),
                      activeThumbColor:
                          neon ? AppTheme.neonGold : AppTheme.champagne,
                      title: Text(
                        meta.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        meta.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      onChanged: (value) async {
                        await prefs.setEnabled(meta.kind, value);
                        await _apply();
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 8, 8),
                    child: Text(
                      'Duyurular ve kazanç fırsatları her zaman açıktır.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
