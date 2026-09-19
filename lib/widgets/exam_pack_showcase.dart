import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exam_pack_model.dart';
import '../screens/exam_pack_detail_screen.dart';
import '../services/exam_catalog_service.dart';
import '../services/exam_pack_service.dart';
import '../services/kpss_preference_service.dart';
import '../services/play_billing_service.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import '../widgets/countdown_widget.dart';

/// Dersler sekmesi altı — yumuşak yatay deneme paketi vitrini.
class ExamPackShowcase extends StatefulWidget {
  final KpssType kpssType;

  const ExamPackShowcase({super.key, required this.kpssType});

  @override
  State<ExamPackShowcase> createState() => _ExamPackShowcaseState();
}

class _ExamPackShowcaseState extends State<ExamPackShowcase> {
  final _svc = ExamPackService.instance;
  final _billing = PlayBillingService.instance;
  final _prefs = KpssPreferenceService.instance;

  String get _catalogExamTypeId =>
      ExamCatalogService.instance.forContentType(widget.kpssType).id;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onChanged);
    _billing.packOwnershipRevision.addListener(_onChanged);
    _prefs.addListener(_onPrefChanged);
    unawaited(_refreshPacks());
  }

  @override
  void didUpdateWidget(covariant ExamPackShowcase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kpssType != widget.kpssType) {
      unawaited(_refreshPacks());
    }
  }

  @override
  void dispose() {
    _svc.removeListener(_onChanged);
    _billing.packOwnershipRevision.removeListener(_onChanged);
    _prefs.removeListener(_onPrefChanged);
    super.dispose();
  }

  Future<void> _refreshPacks() async {
    await _svc.refresh(examTypeId: _catalogExamTypeId);
    if (_svc.packs.isEmpty && _prefs.examTrackId != _catalogExamTypeId) {
      await _svc.refresh(examTypeId: _prefs.examTrackId);
    }
  }

  void _onPrefChanged() {
    unawaited(_refreshPacks());
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final packs = _svc.packs;
    if (_svc.isLoading && packs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 28, 16, 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (packs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'DENEME PAKETLERİ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
                color: AppTheme.champagne.withValues(alpha: 0.72),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 132,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              clipBehavior: Clip.none,
              itemCount: packs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final pack = packs[index];
                return _ExamPackCard(
                  pack: pack,
                  owned: _svc.isPackOwned(pack),
                  priceLabel: _svc.displayPrice(pack),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ExamPackDetailScreen(pack: pack),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamPackCard extends StatelessWidget {
  final ExamPackModel pack;
  final bool owned;
  final String priceLabel;
  final VoidCallback onTap;

  const _ExamPackCard({
    required this.pack,
    required this.owned,
    required this.priceLabel,
    required this.onTap,
  });

  Color get _accent {
    if (pack.subjectId != null && pack.subjectId!.isNotEmpty) {
      return SubjectNeonPalette.forSubject(pack.subjectId!);
    }
    return AppTheme.champagne;
  }

  @override
  Widget build(BuildContext context) {
    final locked = pack.playProductId.isNotEmpty && !owned;

    return SizedBox(
      width: 188,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: _accent.withValues(alpha: 0.08),
          highlightColor: _accent.withValues(alpha: 0.04),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: _accent.withValues(alpha: 0.22),
                width: 0.7,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            pack.isBranch
                                ? Icons.layers_outlined
                                : Icons.fact_check_outlined,
                            color: _accent.withValues(alpha: 0.82),
                            size: 16,
                          ),
                          const Spacer(),
                          if (owned)
                            Text(
                              'Sahipsin',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _accent.withValues(alpha: 0.88),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pack.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.18,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${pack.examCount} deneme'
                        '${pack.timeLimitMinutes > 0 ? ' · ${pack.timeLimitMinutes} dk' : ''}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.48),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        owned ? 'Aç' : priceLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _accent.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                if (locked)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.white.withValues(alpha: 0.55),
                      size: 14,
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
