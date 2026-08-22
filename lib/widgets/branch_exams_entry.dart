import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import 'countdown_widget.dart';

/// Dersler sekmesi altı — branş denemeleri (Tarih, Coğrafya vb.) yer tutucu.
class BranchExamsEntry extends StatelessWidget {
  final KpssType kpssType;

  const BranchExamsEntry({super.key, required this.kpssType});

  static const _branches = [
    _BranchTileData(
      subjectId: 'tarih',
      title: 'Tarih Denemeleri',
      subtitle: 'Branş odaklı deneme serisi — yakında',
    ),
    _BranchTileData(
      subjectId: 'cografya',
      title: 'Coğrafya Denemeleri',
      subtitle: 'Branş odaklı deneme serisi — yakında',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Branş Denemeleri',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.onPage(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tarih, Coğrafya ve diğer branşlara özel deneme paketleri burada olacak.',
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.35,
              color: AppTheme.mutedOnPage(context),
            ),
          ),
          const SizedBox(height: 12),
          ..._branches.map(
            (branch) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BranchExamTile(data: branch),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchTileData {
  final String subjectId;
  final String title;
  final String subtitle;

  const _BranchTileData({
    required this.subjectId,
    required this.title,
    required this.subtitle,
  });
}

class _BranchExamTile extends StatelessWidget {
  final _BranchTileData data;

  const _BranchExamTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final neon = SubjectNeonPalette.forSubject(data.subjectId);
    return Opacity(
      opacity: 0.72,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppTheme.isDark(context)
              ? AppTheme.inkSoft.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.55),
          border: Border.all(color: AppTheme.hairline(context)),
        ),
        child: Row(
          children: [
            Icon(
              switch (data.subjectId) {
                'tarih' => Icons.account_balance_rounded,
                'cografya' => Icons.public_rounded,
                _ => Icons.school_rounded,
              },
              color: neon,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.onPage(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.mutedOnPage(context),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: neon.withValues(alpha: 0.14),
              ),
              child: Text(
                'Yakında',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: neon,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
