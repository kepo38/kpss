import 'package:flutter/material.dart';

import '../constants/studio_modules.dart';
import '../services/app_config_service.dart';
import '../services/premium_service.dart';
import 'countdown_widget.dart';
import '../screens/premium/cloud_sync_screen.dart';
import '../screens/premium/leaderboard_screen.dart';
import '../screens/premium/offline_pack_screen.dart';
import '../screens/premium/task_management_screen.dart';
import '../screens/premium/topic_tracking_screen.dart';
import '../theme/app_theme.dart';
import 'home_module_row.dart';

/// Stüdyo Premium suite listesi.
class HomePremiumModuleList extends StatelessWidget {
  final KpssType kpssType;
  final bool isPremium;
  final Future<void> Function(Widget screen) onNavigate;
  final Future<void> Function(Widget Function() builder) onNavigatePremium;

  const HomePremiumModuleList({
    super.key,
    required this.kpssType,
    required this.isPremium,
    required this.onNavigate,
    required this.onNavigatePremium,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppConfigService.instance,
      builder: (context, _) {
        final cfg = AppConfigService.instance;
        final offlineOn = cfg.isStudioModuleEnabled(StudioModules.offlinePack);
        final canOffline = PremiumService.instance.canUseOfflinePack;

        return Column(
          children: [
            HomeModuleRow(
              icon: Icons.offline_pin_outlined,
              title: 'Offline Paket',
              subtitle: isPremium && canOffline
                  ? 'Kütüphanede internetsiz test'
                  : 'Yalnızca yıllık Premium',
              locked: offlineOn && !canOffline,
              disabled: !offlineOn,
              premiumTone: true,
              tint: AppTheme.champagne,
              onTap: () => onNavigate(const OfflinePackScreen()),
            ),
            HomeModuleRow(
              icon: Icons.checklist_rtl,
              title: 'Konu Takibi',
              subtitle: 'Müfredat ilerlemeni işaretle',
              locked: isPremium == false,
              disabled: !cfg.isStudioModuleEnabled(StudioModules.topicTracking),
              premiumTone: true,
              tint: const Color(0xFF5EEAD4),
              onTap: () => onNavigatePremium(
                () => TopicTrackingScreen(kpssType: kpssType),
              ),
            ),
            HomeModuleRow(
              icon: Icons.task_alt,
              title: 'Görev Yönetimi',
              subtitle: 'Haftalık plan ve öncelikler',
              locked: isPremium == false,
              disabled: !cfg.isStudioModuleEnabled(StudioModules.taskManagement),
              premiumTone: true,
              tint: const Color(0xFF60A5FA),
              onTap: () => onNavigatePremium(() => const TaskManagementScreen()),
            ),
            HomeModuleRow(
              icon: Icons.cloud_outlined,
              title: 'Bulut Senkron',
              subtitle: 'Cihazlar arası senkron',
              locked: isPremium == false,
              disabled: !cfg.isStudioModuleEnabled(StudioModules.cloudSync),
              premiumTone: true,
              tint: const Color(0xFFA78BFA),
              onTap: () => onNavigatePremium(() => const CloudSyncScreen()),
            ),
            HomeModuleRow(
              icon: Icons.leaderboard_outlined,
              title: 'Sıralama',
              subtitle: 'Haftalık ve aylık doğru',
              locked: isPremium == false,
              disabled: !cfg.isStudioModuleEnabled(StudioModules.leaderboard),
              premiumTone: true,
              tint: const Color(0xFFFBBF24),
              onTap: () => onNavigatePremium(() => const LeaderboardScreen()),
            ),
          ],
        );
      },
    );
  }
}
