import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/special_test_models.dart';
import '../screens/special_map_geography_screen.dart';
import '../services/special_tests_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/countdown_widget.dart';

/// Dersler → Özel Testler kategorileri.
class SpecialTestsScreen extends StatefulWidget {
  final KpssType kpssType;

  const SpecialTestsScreen({super.key, required this.kpssType});

  @override
  State<SpecialTestsScreen> createState() => _SpecialTestsScreenState();
}

class _SpecialTestsScreenState extends State<SpecialTestsScreen> {
  final _svc = SpecialTestsService.instance;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onChanged);
    unawaited(_svc.ensureLoaded());
  }

  @override
  void dispose() {
    _svc.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final categories = _svc.categories;

    return Scaffold(
      backgroundColor: AppTheme.page(context),
      appBar: AppBar(
        backgroundColor: AppTheme.page(context),
        foregroundColor: AppTheme.onPage(context),
        leading: const AppBackButton(),
        title: Text(
          'ÖZEL TESTLER',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 1.2,
            color: AppTheme.onPage(context),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.champagne,
        backgroundColor: AppTheme.surfaceCard(context),
        onRefresh: _svc.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            if (_svc.isLoading && categories.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (categories.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _svc.error ?? 'Henüz özel test yok.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.mutedOnPage(context)),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.28,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final category = categories[index];
                      return _SpecialCategoryTile(
                        category: category,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SpecialMapGeographyScreen(
                                kpssType: widget.kpssType,
                                category: category,
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: categories.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpecialCategoryTile extends StatelessWidget {
  final SpecialTestCategory category;
  final VoidCallback onTap;

  const _SpecialCategoryTile({
    required this.category,
    required this.onTap,
  });

  IconData get _icon {
    switch (category.id) {
      case SpecialTestsService.tarihKronolojiId:
        return Icons.timeline_rounded;
      case SpecialTestsService.padisahAntlasmaId:
        return Icons.account_balance_rounded;
      case SpecialTestsService.celdiriciId:
        return Icons.psychology_alt_rounded;
      case SpecialTestsService.mapGeographyId:
      default:
        return Icons.public_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    const neonBlue = Color(0xFF5EEAD4);
    const neonViolet = Color(0xFFA78BFA);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3D2A8C),
                Color(0xFF2B4CB8),
                Color(0xFF5B21B6),
                Color(0xFF1E3A8A),
              ],
              stops: [0.0, 0.38, 0.72, 1.0],
            ),
            border: Border.all(color: neonViolet.withValues(alpha: 0.65)),
            boxShadow: [
              BoxShadow(
                color: neonViolet.withValues(alpha: 0.38),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: neonBlue.withValues(alpha: 0.22),
                blurRadius: 10,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: neonBlue.withValues(alpha: 0.18),
                    border: Border.all(color: neonBlue.withValues(alpha: 0.75)),
                  ),
                  child: Icon(
                    _icon,
                    size: 18,
                    color: neonBlue,
                  ),
                ),
                const Spacer(),
                Text(
                  category.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    height: 1.15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${category.questionCount} soru · ${category.tests.length} test',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: neonBlue.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.north_east_rounded,
                    size: 14,
                    color: neonViolet.withValues(alpha: 0.85),
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
