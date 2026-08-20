import 'package:flutter/material.dart';

import '../screens/analytics_hub_screen.dart';
import 'countdown_widget.dart';
import '../screens/current_info_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/premium/badges_screen.dart';
import '../screens/premium/focus_mode_screen.dart';
import '../screens/premium/statistics_screen.dart';
import '../screens/study_and_solve_screen.dart';
import '../screens/wrong_questions_screen.dart';
import '../theme/app_theme.dart';
import 'home_module_row.dart';

const _mikroOgrenmeScreen = StudyAndSolveScreen(
  dersAdi: 'Türkçe',
  konuAdi: 'Anlam Bilgisi',
  altKonuAdi: 'Sözcükte Anlam',
  anlatimMetni:
      'Sözcükte anlam, bir kelimenin cümle içindeki kullanımına '
      'göre kazandığı anlamdır. Gerçek anlam, kelimenin ilk '
      'akla gelen temel anlamıdır. Mecaz anlam ise kelimenin '
      'gerçek anlamından uzaklaşarak kazandığı yeni anlamdır.\n\n'
      'Yan anlam, kelimenin gerçek anlamından türeyen ve '
      'yakınlık bağı bulunan anlamlardır. Terim anlam ise '
      'belirli bir bilim veya sanat dalında kullanılan özel '
      'anlamdır.',
);

/// Ana sayfa "Diğer araçlar" modül listesi.
class HomeToolsModuleList extends StatelessWidget {
  final KpssType kpssType;
  final Future<void> Function(Widget screen) onNavigate;
  final Future<void> Function(Widget Function() builder) onNavigatePremium;

  const HomeToolsModuleList({
    super.key,
    required this.kpssType,
    required this.onNavigate,
    required this.onNavigatePremium,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HomeModuleRow(
          icon: Icons.menu_book_outlined,
          title: 'Mikro Öğrenme',
          subtitle: 'Kısa anlatım, hızlı pekiştirme',
          tint: const Color(0xFF5EEAD4),
          onTap: () => onNavigate(_mikroOgrenmeScreen),
        ),
        HomeModuleRow(
          icon: Icons.favorite_border,
          title: 'Favorilerim',
          subtitle: 'İşaretlediğin sorular',
          tint: const Color(0xFFE879A9),
          onTap: () => onNavigate(const FavoritesScreen()),
        ),
        HomeModuleRow(
          icon: Icons.note_alt_outlined,
          title: 'Yanlış Defteri',
          subtitle: 'Testlerde yanlış yaptığın sorular',
          tint: const Color(0xFFF87171),
          onTap: () => onNavigate(const WrongQuestionsScreen()),
        ),
        HomeModuleRow(
          icon: Icons.timer_outlined,
          title: 'Odak · Pomodoro',
          subtitle: 'İdeal 25 dk · derin çalışma',
          accent: true,
          tint: const Color(0xFFFBBF24),
          onTap: () => onNavigatePremium(() => const FocusModeScreen()),
        ),
        HomeModuleRow(
          icon: Icons.insights_outlined,
          title: 'Performans',
          subtitle: 'Ders bazlı performans özeti',
          accent: true,
          tint: const Color(0xFF60A5FA),
          onTap: () => onNavigate(AnalyticsHubScreen(kpssType: kpssType)),
        ),
        HomeModuleRow(
          icon: Icons.analytics_outlined,
          title: 'Deneme Analizi',
          subtitle: 'GK/GY, yayın evi, haftalık özet',
          tint: const Color(0xFFA78BFA),
          onTap: () => onNavigatePremium(() => const StatisticsScreen()),
        ),
        HomeModuleRow(
          icon: Icons.newspaper_outlined,
          title: 'Güncel Bilgiler',
          subtitle: 'Sınava özel gelişmeler',
          tint: const Color(0xFF34D399),
          onTap: () => onNavigate(const CurrentInfoScreen()),
        ),
        HomeModuleRow(
          icon: Icons.emoji_events_outlined,
          title: 'Rozetler',
          subtitle: 'XP, seri, günlük hedef',
          accent: true,
          tint: AppTheme.champagne,
          onTap: () => onNavigate(const BadgesScreen()),
        ),
      ],
    );
  }
}
