import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/question_model.dart';
import '../services/ad_manager.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/scale_button.dart';
import 'quiz_screen.dart';

/// Mikro öğrenme modülü — kısa anlatım + pekiştirme testi.
class StudyAndSolveScreen extends StatefulWidget {
  final String dersAdi;
  final String konuAdi;
  final String altKonuAdi;
  final String anlatimMetni;

  const StudyAndSolveScreen({
    super.key,
    required this.dersAdi,
    required this.konuAdi,
    required this.altKonuAdi,
    required this.anlatimMetni,
  });

  @override
  State<StudyAndSolveScreen> createState() => _StudyAndSolveScreenState();
}

class _StudyAndSolveScreenState extends State<StudyAndSolveScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(widget.altKonuAdi),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Breadcrumb(
              ders: widget.dersAdi,
              konu: widget.konuAdi,
              altKonu: widget.altKonuAdi,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.menu_book_outlined,
                            color: AppTheme.lightAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Konu Anlatımı',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.lightPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.anlatimMetni,
                      style: GoogleFonts.inter(fontSize: 15, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ScaleButton(
                onPressed: _startMicroTest,
                child: FilledButton.icon(
                  onPressed: _startMicroTest,
                  icon: const Icon(Icons.quiz_outlined),
                  label: const Text('Konuyu Pekiştir: Testi Çöz'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startMicroTest() async {
    final questions = await DatabaseService.instance
        .getQuestionsByAltKonu(widget.altKonuAdi);

    if (!mounted) return;

    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu alt konu için henüz soru eklenmemiş.')),
      );
      return;
    }

    AdManager.instance.skipNextPageTransition();

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizScreen(
          title: widget.altKonuAdi,
          questions: questions,
        ),
      ),
    );
  }

}

class _Breadcrumb extends StatelessWidget {
  final String ders;
  final String konu;
  final String altKonu;

  const _Breadcrumb({
    required this.ders,
    required this.konu,
    required this.altKonu,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '$ders › $konu › $altKonu',
      style: GoogleFonts.inter(
        fontSize: 13,
        color: AppTheme.lightAccent,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
