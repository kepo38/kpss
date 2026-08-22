import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/publisher_constants.dart';
import '../../models/practice_exam_model.dart';
import '../../services/practice_exam_service.dart';
import '../../theme/app_theme.dart';

/// GK/GY ders bazlı detaylı deneme kayıt formu.
class AddExamSheet extends StatefulWidget {
  const AddExamSheet({super.key});

  @override
  State<AddExamSheet> createState() => _AddExamSheetState();
}

class _AddExamSheetState extends State<AddExamSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _publisher = PublisherConstants.yayinEvleri.first;
  DateTime _date = DateTime.now();

  final Map<String, _ScoreInput> _scores = {
    for (final d in [
      ...PracticeExamModel.genelYetenekDersleri,
      ...PracticeExamModel.genelKulturDersleri,
    ])
      d: _ScoreInput()..syncBos(PracticeExamModel.soruSayisi(d)),
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    for (final s in _scores.values) {
      s.dispose();
    }
    super.dispose();
  }

  double get _previewGy => PracticeExamModel.genelYetenekDersleri
      .where(_scores.containsKey)
      .fold(
        0.0,
        (sum, d) =>
            sum +
            _scores[d]!
                .toSonuc(totalQuestions: PracticeExamModel.soruSayisi(d))
                .net,
      );

  double get _previewGk => PracticeExamModel.genelKulturDersleri
      .where(_scores.containsKey)
      .fold(
        0.0,
        (sum, d) =>
            sum +
            _scores[d]!
                .toSonuc(totalQuestions: PracticeExamModel.soruSayisi(d))
                .net,
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                  child: Row(
                    children: [
                      Text(
                        'Deneme Kaydı',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Deneme adı',
                            hintText: 'Örn: Palme Genel Deneme 4',
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Deneme adı gerekli'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _publisher,
                          decoration:
                              const InputDecoration(labelText: 'Yayın evi'),
                          items: PublisherConstants.yayinEvleri
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _publisher = v!),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Deneme tarihi'),
                          subtitle: Text(
                            '${_date.day}.${_date.month}.${_date.year}',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _date = picked);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _PreviewCard(gy: _previewGy, gk: _previewGk),
                        const SizedBox(height: 20),
                        _SectionHeader(
                          title: 'Genel Yetenek',
                          icon: Icons.psychology_outlined,
                          color: AppTheme.lightPrimary,
                        ),
                        ...PracticeExamModel.genelYetenekDersleri.map(
                          (d) => _ScoreRow(
                            label: d,
                            totalQuestions: PracticeExamModel.soruSayisi(d),
                            input: _scores[d]!,
                            onChanged: () => setState(() {}),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionHeader(
                          title: 'Genel Kültür',
                          icon: Icons.public_outlined,
                          color: AppTheme.lightAccent,
                        ),
                        ...PracticeExamModel.genelKulturDersleri.map(
                          (d) => _ScoreRow(
                            label: d,
                            totalQuestions: PracticeExamModel.soruSayisi(d),
                            input: _scores[d]!,
                            onChanged: () => setState(() {}),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Notlar (isteğe bağlı)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.shade300.withValues(alpha: 0.65),
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Denemeyi Kaydet'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    for (final entry in _scores.entries) {
      final total = PracticeExamModel.soruSayisi(entry.key);
      final sonuc = entry.value.toSonuc(totalQuestions: total);
      final sum = sonuc.dogru + sonuc.yanlis + sonuc.bos;
      if (sum != total) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${entry.key}: D+Y+B = $sum olmalı, soru sayısı $total.',
            ),
          ),
        );
        return;
      }
    }

    final dersSonuclari = {
      for (final e in _scores.entries)
        e.key: e.value.toSonuc(
          totalQuestions: PracticeExamModel.soruSayisi(e.key),
        ),
    };

    await PracticeExamService.instance.addExam(PracticeExamModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      denemeAdi: _nameCtrl.text.trim(),
      yayinEvi: _publisher,
      tarih: _date,
      dersSonuclari: dersSonuclari,
      notlar: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    ));

    if (!mounted) return;
    Navigator.pop(context, true);
  }
}

class _ScoreInput {
  final dogru = TextEditingController(text: '0');
  final yanlis = TextEditingController(text: '0');
  final bos = TextEditingController();

  DersSonuc toSonuc({int? totalQuestions}) {
    final d = int.tryParse(dogru.text) ?? 0;
    final y = int.tryParse(yanlis.text) ?? 0;
    var b = int.tryParse(bos.text);
    if (totalQuestions != null && (bos.text.trim().isEmpty || b == null)) {
      b = (totalQuestions - d - y).clamp(0, totalQuestions);
    }
    return DersSonuc(dogru: d, yanlis: y, bos: b ?? 0);
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 13)),
                Text(
                  '$totalQuestions soru',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: input.dogru,
              keyboardType: TextInputType.number,
              onChanged: (_) {
                input.syncBos(totalQuestions);
                onChanged();
              },
              decoration: const InputDecoration(
                labelText: 'D',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: input.yanlis,
              keyboardType: TextInputType.number,
              onChanged: (_) {
                input.syncBos(totalQuestions);
                onChanged();
              },
              decoration: const InputDecoration(
                labelText: 'Y',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: input.bos,
              keyboardType: TextInputType.number,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: 'B',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final double gy;
  final double gk;

  const _PreviewCard({required this.gy, required this.gk});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.lightPrimary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _PreviewItem(label: 'GY Net', value: gy),
            _PreviewItem(label: 'GK Net', value: gk),
            _PreviewItem(label: 'Toplam', value: gy + gk, bold: true),
          ],
        ),
      ),
    );
  }
}

class _PreviewItem extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;

  const _PreviewItem({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12)),
        Text(
          value.toStringAsFixed(2),
          style: GoogleFonts.inter(
            fontSize: bold ? 20 : 16,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: AppTheme.lightPrimary,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
