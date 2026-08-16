import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/brand_constants.dart';
import '../models/current_info_model.dart';
import '../services/ad_manager.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/scale_button.dart';
import 'package:share_plus/share_plus.dart';

/// Instagram hikayeleri tarzında güncel bilgiler sayfası.
class CurrentInfoScreen extends StatefulWidget {
  const CurrentInfoScreen({super.key});

  @override
  State<CurrentInfoScreen> createState() => _CurrentInfoScreenState();
}

class _CurrentInfoScreenState extends State<CurrentInfoScreen> {
  late Future<List<CurrentInfoModel>> _infosFuture;
  final PageController _pageController = PageController(viewportFraction: 0.85);
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
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Güncel Bilgiler'),
      ),
      body: FutureBuilder<List<CurrentInfoModel>>(
        future: _infosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final infos = snapshot.data ?? [];
          if (infos.isEmpty) {
            return const Center(child: Text('Henüz güncel bilgi yok.'));
          }

          return Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: infos.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final info = infos[index];
                    return AnimatedScale(
                      scale: _currentPage == index ? 1.0 : 0.92,
                      duration: const Duration(milliseconds: 300),
                      child: _InfoCard(info: info),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  infos.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? AppTheme.lightPrimary
                          : AppTheme.lightAccent.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: ScaleButton(
                  onPressed: () => _shareInfo(infos[_currentPage]),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _shareInfo(infos[_currentPage]),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Paylaş'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

}

class _InfoCard extends StatelessWidget {
  final CurrentInfoModel info;

  const _InfoCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (info.imageUrl != null)
            Image.network(
              info.imageUrl!,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _PlaceholderImage(),
            )
          else
            const _PlaceholderImage(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.baslik,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        info.aciklama,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          height: 1.5,
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
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.lightPrimary,
            AppTheme.lightPrimary.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.newspaper_outlined,
          size: 64,
          color: AppTheme.lightAccent.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
