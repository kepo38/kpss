import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/brand_constants.dart';
import '../models/user_model.dart';
import '../screens/main_shell.dart';
import '../services/kpss_preference_service.dart';
import '../theme/app_theme.dart';
import '../widgets/countdown_widget.dart';

/// Google girişinden sonra hedef sınavı bir kez sorar.
class ExamTrackOnboardingScreen extends StatefulWidget {
  final UserModel user;

  const ExamTrackOnboardingScreen({super.key, required this.user});

  @override
  State<ExamTrackOnboardingScreen> createState() =>
      _ExamTrackOnboardingScreenState();
}

class _ExamTrackOnboardingScreenState extends State<ExamTrackOnboardingScreen> {
  ExamTrack? _hover;

  void _select(ExamTrack track) {
    setState(() => _hover = track);
    unawaited(KpssPreferenceService.instance.setExamTrack(track));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MainShell(user: widget.user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                BrandConstants.brandLine1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 18,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.champagne.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Hangi sınava\nhazırlanıyorsun?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 30,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Sayaç yalnızca seçtiğin sınavın tarihini ve kalan süresini gösterir. Profilinden dilediğin zaman değiştirebilirsin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.52),
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView(
                  children: [
                    for (final track in ExamTrack.defaults)
                      _ExamChoiceCard(
                        track: track,
                        selected: _hover?.id == track.id,
                        onTap: () => _select(track),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamChoiceCard extends StatelessWidget {
  final ExamTrack track;
  final bool selected;
  final VoidCallback onTap;

  const _ExamChoiceCard({
    required this.track,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    final date = track.nextExamDate();
    final dateLabel = track.hasUpcomingDate()
        ? '${date.day} ${months[date.month - 1]} ${date.year}'
        : 'Yeni tarih ÖSYM tarafından açıklanacak';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppTheme.champagne
                    : AppTheme.champagne.withValues(alpha: 0.28),
                width: selected ? 1.6 : 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selected
                    ? [
                        AppTheme.champagne.withValues(alpha: 0.22),
                        AppTheme.inkSoft,
                      ]
                    : [
                        AppTheme.inkSoft,
                        const Color(0xFF121A2C),
                      ],
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppTheme.champagne.withValues(alpha: 0.22),
                        blurRadius: 18,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppTheme.champagne.withValues(alpha: 0.14),
                    border: Border.all(
                      color: AppTheme.champagne.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(track.icon, color: AppTheme.champagneLight),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.label,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.description,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.champagneLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppTheme.champagne.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
