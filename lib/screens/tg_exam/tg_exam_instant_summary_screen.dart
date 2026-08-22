import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/tg_exam_models.dart';
import '../../screens/quiz_screen.dart';
import '../../services/question_fetch_service.dart';
import '../../theme/app_theme.dart';
import 'tg_exam_result_screen.dart';

/// Sınav bitişi anlık özet — yalnızca temel metrikler; çözümler kilitli kalabilir.
class TgExamInstantSummaryScreen extends StatefulWidget {
  final TgExamModel exam;

  const TgExamInstantSummaryScreen({super.key, required this.exam});

  @override
  State<TgExamInstantSummaryScreen> createState() =>
      _TgExamInstantSummaryScreenState();
}

class _TgExamInstantSummaryScreenState
    extends State<TgExamInstantSummaryScreen> {
  late TgExamModel _exam;
  bool _loadingSolutions = false;

  @override
  void initState() {
    super.initState();
    _exam = widget.exam;
  }

  String get _unlockLabel {
    final fmt = DateFormat('d MMMM yyyy HH:mm', 'tr');
    return fmt.format(_exam.endAt);
  }

  Future<void> _openSolutions() async {
    if (!_exam.canAccessSolutions || _loadingSolutions) return;
    setState(() => _loadingSolutions = true);
    await TgExamResultScreen.openSolutionsReview(context, _exam);
    if (mounted) setState(() => _loadingSolutions = false);
  }

  void _openDetailedAnalysis() {
    if (!_exam.canAccessDetailedAnalysis) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TgExamResultScreen(exam: _exam),
      ),
    );
  }

  void _finish() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final attempt = _exam.myAttempt;
    final canSolutions = _exam.canAccessSolutions;
    final canAnalysis = _exam.canAccessDetailedAnalysis;

    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.inkSoft,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Sınav Özeti',
          style: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _finish,
            child: const Text(
              'Tamam',
              style: TextStyle(
                color: AppTheme.champagne,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.champagne.withValues(alpha: 0.18),
                    AppTheme.inkSoft,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: Border.all(
                  color: AppTheme.champagne.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 44,
                    color: AppTheme.champagne.withValues(alpha: 0.95),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tebrikler!',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _exam.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 15,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cevapların kaydedildi ve puanın hesaplandı.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Temel Metrikler',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppTheme.champagne,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Doğru',
                    value: '${attempt?.correct ?? 0}',
                    color: const Color(0xFF34D399),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Yanlış',
                    value: '${attempt?.wrong ?? 0}',
                    color: const Color(0xFFF87171),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Boş',
                    value: '${attempt?.blank ?? 0}',
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MetricTile(
              label: 'Ham Puan / Net',
              value:
                  '${attempt?.correct ?? 0} doğru · ${(attempt?.net ?? 0).toStringAsFixed(2)} net',
              color: AppTheme.champagneLight,
              wide: true,
            ),
            const SizedBox(height: 28),
            _LockedActionButton(
              enabled: canSolutions,
              loading: _loadingSolutions,
              icon: Icons.menu_book_outlined,
              label: 'Soruları ve Çözümleri İncele',
              lockHint: canSolutions
                  ? null
                  : 'Türkiye Geneli sınav süresi devam ettiği için soru '
                      'çözümleri, sıralama ve detaylı analizler '
                      '$_unlockLabel\'de otomatik olarak açılacaktır.',
              onPressed: _openSolutions,
            ),
            if (canAnalysis) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openDetailedAnalysis,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Detaylı Analiz'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.champagne,
                  foregroundColor: AppTheme.ink,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (!canSolutions)
              Text(
                'Sıralama ve Türkiye geneli karşılaştırma, sonuçlar '
                'açıklandığında Denemelerim sekmesinde görünecek.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.48),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool wide;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 18 : 12,
        vertical: wide ? 16 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment:
            wide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.52),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: wide ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: wide ? 18 : 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedActionButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final IconData icon;
  final String label;
  final String? lockHint;
  final VoidCallback onPressed;

  const _LockedActionButton({
    required this.enabled,
    required this.loading,
    required this.icon,
    required this.label,
    required this.lockHint,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: enabled && !loading ? onPressed : null,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 20),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: enabled ? AppTheme.champagne : Colors.white38,
            side: BorderSide(
              color: enabled
                  ? AppTheme.champagne.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.14),
            ),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        if (lockHint != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline,
                size: 14,
                color: Colors.white.withValues(alpha: 0.38),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  lockHint!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.42),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
