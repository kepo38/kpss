import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exam_pack_model.dart';
import '../screens/exam_pack_detail_screen.dart';
import '../services/exam_pack_service.dart';
import '../services/play_billing_service.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';

/// Dersler sekmesi altında yatay deneme paketi vitrini.
class ExamPackShowcase extends StatefulWidget {
  final String examTypeId;

  const ExamPackShowcase({super.key, required this.examTypeId});

  @override
  State<ExamPackShowcase> createState() => _ExamPackShowcaseState();
}

class _ExamPackShowcaseState extends State<ExamPackShowcase> {
  final _svc = ExamPackService.instance;
  final _billing = PlayBillingService.instance;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onChanged);
    _billing.packOwnershipRevision.addListener(_onChanged);
    unawaited(_svc.refresh(examTypeId: widget.examTypeId));
  }

  @override
  void didUpdateWidget(covariant ExamPackShowcase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.examTypeId != widget.examTypeId) {
      unawaited(_svc.refresh(examTypeId: widget.examTypeId));
    }
  }

  @override
  void dispose() {
    _svc.removeListener(_onChanged);
    _billing.packOwnershipRevision.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final packs = _svc.packs;
    if (_svc.isLoading && packs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (packs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppTheme.champagne,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Deneme Paketleri',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 168,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: packs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
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

  Color get _neon {
    if (pack.subjectId != null && pack.subjectId!.isNotEmpty) {
      return SubjectNeonPalette.forSubject(pack.subjectId!);
    }
    return AppTheme.neonGold;
  }

  @override
  Widget build(BuildContext context) {
    final locked = pack.playProductId.isNotEmpty && !owned;

    return SizedBox(
      width: 220,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: SubjectNeonPalette.lightNeonModule(
              neon: _neon,
              accent: true,
              radius: 16,
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            pack.isBranch
                                ? Icons.layers_outlined
                                : Icons.fact_check_outlined,
                            color: _neon,
                            size: 20,
                          ),
                          const Spacer(),
                          if (owned)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _neon.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Sahipsin',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _neon,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pack.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${pack.examCount} deneme'
                        '${pack.questionsPerExam > 0 ? ' · ${pack.questionsPerExam} soru' : ''}'
                        '${pack.timeLimitMinutes > 0 ? ' · ${pack.timeLimitMinutes} dk' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        owned ? 'Aç' : priceLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _neon,
                        ),
                      ),
                    ],
                  ),
                ),
                if (locked)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.22),
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.lock_rounded,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 18,
                        ),
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
