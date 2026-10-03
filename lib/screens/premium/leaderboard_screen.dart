import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/leaderboard_model.dart';
import '../../services/daily_mini_ranking_service.dart';
import '../../services/leaderboard_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardPeriod _period = LeaderboardPeriod.haftalik;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(DailyMiniRankingService.instance.refresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DailyMiniRankingService.instance,
      builder: (context, _) {
        final entries = LeaderboardService.instance.getEntries(_period);
        final loading = DailyMiniRankingService.instance.loading &&
            entries.every((e) => e.totalCorrect == 0);

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(),
            title: const Text('Sıralama'),
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SegmentedButton<LeaderboardPeriod>(
                        segments: const [
                          ButtonSegment(
                            value: LeaderboardPeriod.haftalik,
                            label: Text('Haftalık'),
                          ),
                          ButtonSegment(
                            value: LeaderboardPeriod.aylik,
                            label: Text('Aylık'),
                          ),
                        ],
                        selected: {_period},
                        onSelectionChanged: (s) =>
                            setState(() => _period = s.first),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () =>
                            DailyMiniRankingService.instance.refresh(force: true),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: entries.length,
                          itemBuilder: (context, i) {
                            final e = entries[i];
                            return _LeaderboardTile(entry: e);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final LeaderboardEntryModel entry;

  const _LeaderboardTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isMe = entry.benMi;
    return Card(
      color: isMe ? AppTheme.lightPrimary.withValues(alpha: 0.08) : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.sira <= 3
              ? AppTheme.lightAccent
              : AppTheme.lightPrimary.withValues(alpha: 0.1),
          child: Text(
            '${entry.sira}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: entry.sira <= 3 ? Colors.white : AppTheme.lightPrimary,
            ),
          ),
        ),
        title: Text(
          entry.isim,
          style: GoogleFonts.inter(
            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Text(
          '${entry.totalCorrect} doğru',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: AppTheme.lightAccent,
          ),
        ),
      ),
    );
  }
}
