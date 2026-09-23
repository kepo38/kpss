import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/brand_constants.dart';
import '../models/current_info_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/scale_button.dart';

/// Hikaye-tarzı özel notlar — premium kart carousel.
class CurrentInfoScreen extends StatefulWidget {
  const CurrentInfoScreen({super.key});

  @override
  State<CurrentInfoScreen> createState() => _CurrentInfoScreenState();
}

class _CurrentInfoScreenState extends State<CurrentInfoScreen> {
  late Future<List<CurrentInfoModel>> _infosFuture;
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _infosFuture = DatabaseService.instance.getCurrentInfos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _shareInfo(CurrentInfoModel info) {
    Share.share(
      '${info.baslik}\n\n${info.aciklama}\n\n— ${BrandConstants.appName}',
      subject: info.baslik,
    );
  }

  @override
  Widget build(BuildContext context) {
    final onPage = AppTheme.onPage(context);

    return Scaffold(
      backgroundColor: AppTheme.page(context),
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppTheme.page(context),
        foregroundColor: onPage,
        elevation: 0,
        title: Text(
          'Özel Notlarım',
          style: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w700,
            color: onPage,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.pageTop(context),
              AppTheme.page(context),
              AppTheme.pageDeep(context),
            ],
          ),
        ),
        child: FutureBuilder<List<CurrentInfoModel>>(
          future: _infosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final infos = snapshot.data ?? [];
            if (infos.isEmpty) {
              return Center(
                child: Text(
                  'Henüz özel not yok.',
                  style: TextStyle(color: AppTheme.mutedOnPage(context)),
                ),
              );
            }

            final bottomInset = MediaQuery.paddingOf(context).bottom;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: Text(
                    'Kişisel kartlarını kaydırarak gez · paylaş',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppTheme.mutedOnPage(context),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: infos.length,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemBuilder: (context, index) {
                      final info = infos[index];
                      return AnimatedScale(
                        scale: _currentPage == index ? 1.0 : 0.94,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        child: _InfoCard(
                          info: info,
                          active: _currentPage == index,
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PageIndicators(
                        count: infos.length,
                        current: _currentPage,
                      ),
                      const SizedBox(height: 14),
                      ScaleButton(
                        onPressed: () => _shareInfo(infos[_currentPage]),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.ink,
                                AppTheme.inkSoft,
                              ],
                            ),
                            border: Border.all(
                              color: AppTheme.champagne.withValues(alpha: 0.45),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.ink.withValues(alpha: 0.22),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _shareInfo(infos[_currentPage]),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  18,
                                  14,
                                  18,
                                  14 + (bottomInset > 0 ? 0 : 2),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.ios_share_rounded,
                                      size: 20,
                                      color: AppTheme.champagneLight,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Paylaş',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                        color: AppTheme.champagneLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PageIndicators extends StatelessWidget {
  final int count;
  final int current;

  const _PageIndicators({
    required this.count,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = current == i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: active
                ? const LinearGradient(
                    colors: [AppTheme.ink, AppTheme.inkSoft],
                  )
                : null,
            color: active
                ? null
                : AppTheme.champagne.withValues(alpha: 0.35),
            border: active
                ? Border.all(
                    color: AppTheme.champagne.withValues(alpha: 0.5),
                  )
                : null,
          ),
        );
      }),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final CurrentInfoModel info;
  final bool active;

  const _InfoCard({
    required this.info,
    required this.active,
  });

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${date.day}.${date.month}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppTheme.ink.withValues(alpha: active ? 0.2 : 0.1),
              blurRadius: active ? 28 : 16,
              offset: Offset(0, active ? 12 : 8),
            ),
            BoxShadow(
              color: AppTheme.champagne.withValues(alpha: active ? 0.12 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Material(
            color: AppTheme.surfaceCard(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (info.imageUrl != null)
                  Image.network(
                    info.imageUrl!,
                    height: 196,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _CardHero(),
                  )
                else
                  const _CardHero(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.champagne.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color:
                                      AppTheme.champagne.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                'ÖZEL NOT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.14,
                                  color: AppTheme.champagne.withValues(alpha: 0.95),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _relativeDate(info.eklenmeTarihi),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.mutedOnPage(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          info.baslik,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 22,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: AppTheme.onPage(context),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 2,
                          width: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.champagne,
                                AppTheme.champagneLight,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Text(
                              info.aciklama,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.55,
                                color: AppTheme.mutedOnPage(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardHero extends StatelessWidget {
  const _CardHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 196,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.ink,
                  AppTheme.inkSoft,
                  Color(0xFF101A2C),
                ],
              ),
            ),
          ),
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.champagne.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -18,
            bottom: -20,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.neonEdge.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: AppTheme.champagne.withValues(alpha: 0.45),
                ),
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                size: 34,
                color: AppTheme.champagneLight.withValues(alpha: 0.92),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
