import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/practice_exam_model.dart';
import '../services/kpss_score_calculator_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';

/// GY–GK netlerinden tahmini KPSS P3 puanı hesaplama.
class PuanHesaplamaScreen extends StatefulWidget {
  const PuanHesaplamaScreen({super.key});

  @override
  State<PuanHesaplamaScreen> createState() => _PuanHesaplamaScreenState();
}

class _PuanHesaplamaScreenState extends State<PuanHesaplamaScreen> {
  final Map<String, _ScoreInput> _scores = {
    for (final d in [
      ...PracticeExamModel.genelYetenekDersleri,
      ...PracticeExamModel.genelKulturDersleri,
    ])
      d: _ScoreInput()..syncBos(PracticeExamModel.soruSayisi(d)),
  };

  @override
  void dispose() {
    for (final input in _scores.values) {
      input.dispose();
    }
    super.dispose();
  }

  Map<String, DersSonuc> get _dersSonuclari => {
        for (final entry in _scores.entries)
          entry.key: entry.value.toSonuc(
            totalQuestions: PracticeExamModel.soruSayisi(entry.key),
          ),
      };

  KpssScoreEstimate get _estimate =>
      KpssScoreCalculatorService.estimate(_dersSonuclari);

  @override
  Widget build(BuildContext context) {
    final estimate = _estimate;
    final on = AppTheme.onPage(context);
    final muted = AppTheme.mutedOnPage(context);

    return Scaffold(
      backgroundColor: AppTheme.page(context),
      appBar: AppBar(
        backgroundColor: AppTheme.page(context),
        foregroundColor: on,
        leading: const AppBackButton(),
        title: const Text(
          'Puan Hesaplama',
          style: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
            fontSize: 20,
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _ResultHeroCard(estimate: estimate),
            const SizedBox(height: 18),
            Text(
              'DERS NETLERİ',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
                color: AppTheme.champagne.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Doğru / yanlış / boş gir — netler anında güncellenir',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 14),
            _SectionLabel(
              title: 'Genel Yetenek',
              icon: Icons.psychology_alt_outlined,
            ),
            ...PracticeExamModel.genelYetenekDersleri.map(
              (d) => _ScoreRow(
                label: d,
                totalQuestions: PracticeExamModel.soruSayisi(d),
                input: _scores[d]!,
                onChanged: () => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),
            _SectionLabel(
              title: 'Genel Kültür',
              icon: Icons.public_outlined,
            ),
            ...PracticeExamModel.genelKulturDersleri.map(
              (d) => _ScoreRow(
                label: d,
                totalQuestions: PracticeExamModel.soruSayisi(d),
                input: _scores[d]!,
                onChanged: () => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),
            _Disclaimer(muted: muted),
          ],
        ),
      ),
    );
  }
}

class _ResultHeroCard extends StatelessWidget {
  final KpssScoreEstimate estimate;

  const _ResultHeroCard({required this.estimate});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4AF6A).withValues(alpha: 0.85),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF6E3),
                Color(0xFFF1DEB8),
                Color(0xFFE2C885),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TAHMİNİ P3',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  estimate.p3Score.toStringAsFixed(2),
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 42,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'GY-Net',
                        value: estimate.gyNet.toStringAsFixed(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: 'GK-Net',
                        value: estimate.gkNet.toStringAsFixed(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: 'Toplam',
                        value: estimate.totalNet.toStringAsFixed(2),
                        sub: 'net',
                        bold: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final bool bold;

  const _MiniStat({
    required this.label,
    required this.value,
    this.sub,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.ink.withValues(alpha: 0.06),
        border: Border.all(color: AppTheme.ink.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: bold ? 18 : 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          if (sub != null && sub!.isNotEmpty)
            Text(
              sub!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionLabel({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.champagne),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.onPage(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreInput {
  final dogru = TextEditingController(text: '0');
  final yanlis = TextEditingController(text: '0');
  final bos = TextEditingController();

  DersSonuc toSonuc({required int totalQuestions}) {
    final d = int.tryParse(dogru.text) ?? 0;
    final y = int.tryParse(yanlis.text) ?? 0;
    var b = int.tryParse(bos.text);
    if (bos.text.trim().isEmpty || b == null) {
      b = (totalQuestions - d - y).clamp(0, totalQuestions);
    }
    return DersSonuc(dogru: d, yanlis: y, bos: b);
  }

  void syncBos(int totalQuestions) {
    final d = int.tryParse(dogru.text) ?? 0;
    final y = int.tryParse(yanlis.text) ?? 0;
    final b = (totalQuestions - d - y).clamp(0, totalQuestions);
    bos.text = '$b';
  }

  void dispose() {
    dogru.dispose();
    yanlis.dispose();
    bos.dispose();
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final int totalQuestions;
  final _ScoreInput input;
  final VoidCallback onChanged;

  const _ScoreRow({
    required this.label,
    required this.totalQuestions,
    required this.input,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final card = AppTheme.surfaceCard(context);
    final on = AppTheme.onPage(context);
    final muted = AppTheme.mutedOnPage(context);
    final sonuc = input.toSonuc(totalQuestions: totalQuestions);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: card.withValues(alpha: 0.9),
          border: Border.all(color: AppTheme.hairline(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: on,
                    ),
                  ),
                ),
                Text(
                  '${sonuc.net.toStringAsFixed(2)} net',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.champagne.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$totalQuestions soru',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ScoreField(
                    label: 'D',
                    controller: input.dogru,
                    onChanged: (_) {
                      input.syncBos(totalQuestions);
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ScoreField(
                    label: 'Y',
                    controller: input.yanlis,
                    onChanged: (_) {
                      input.syncBos(totalQuestions);
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ScoreField(
                    label: 'B',
                    controller: input.bos,
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _ScoreField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: AppTheme.onPage(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: AppTheme.page(context).withValues(alpha: 0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.hairline(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.hairline(context)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  final Color muted;

  const _Disclaimer({required this.muted});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.champagne.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.champagne.withValues(alpha: 0.22)),
      ),
      child: Text(
        'Bu ekrandaki puan tahminidir; ÖSYM’nin resmi standart puan '
        'hesaplamasından farklı olabilir.',
        style: TextStyle(
          fontSize: 11.5,
          height: 1.4,
          fontWeight: FontWeight.w500,
          color: muted,
        ),
      ),
    );
  }
}
