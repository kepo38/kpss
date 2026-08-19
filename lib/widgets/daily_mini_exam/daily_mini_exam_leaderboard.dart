import 'package:flutter/material.dart';

import '../../constants/brand_constants.dart';
import '../../models/daily_mini_exam_models.dart';
import '../../services/auth_service.dart';
import '../../services/daily_mini_exam_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/daily_mini_exam_logic.dart';
import 'daily_mini_exam_rank_reveal.dart';

class DailyMiniExamCompletedPending extends StatelessWidget {
  final VoidCallback onRefresh;

  const DailyMiniExamCompletedPending({
    super.key,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.champagne.withValues(alpha: 0.1),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            color: AppTheme.champagneLight,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Denemen tamamlandı. Sonucun yükleniyor…',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.champagneLight,
              ),
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Yenile',
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppTheme.champagneLight,
            ),
          ),
        ],
      ),
    );
  }
}

class DailyMiniExamLeaderboardPreview extends StatelessWidget {
  final List<DailyMiniLeaderRow> leaders;
  final int participantCount;
  final int totalQuestions;
  final String headline;
  final String footer;

  const DailyMiniExamLeaderboardPreview({
    super.key,
    required this.leaders,
    required this.participantCount,
    required this.totalQuestions,
    this.headline = 'BUGÜNÜN KÜRSÜSÜ',
    this.footer = 'Denemeyi bitirince sıralamana burada yer verilir.',
  });

  @override
  Widget build(BuildContext context) {
    final topThree = [...leaders]..sort((a, b) => a.rank.compareTo(b.rank));

    return _LeaderboardShell(
      child: Column(
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 22, height: 1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Color(0xFFF5E6BC),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppTheme.champagne.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  participantCount > 0 ? '$participantCount kişi' : 'Demo',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.champagneLight.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DailyMiniPodium(
            leaders: topThree,
            totalQuestions: totalQuestions,
          ),
          const SizedBox(height: 8),
          Text(
            footer,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class DailyMiniExamCompletedLeaderboard extends StatelessWidget {
  final int? rank;
  final int participantCount;
  final List<DailyMiniLeaderRow> leaders;
  final int totalQuestions;
  final DailyMiniRankTrend trend;
  final VoidCallback onShare;
  final VoidCallback onDetails;
  final GlobalKey shareBoundaryKey;

  const DailyMiniExamCompletedLeaderboard({
    super.key,
    required this.rank,
    required this.participantCount,
    required this.leaders,
    required this.totalQuestions,
    required this.trend,
    required this.onShare,
    required this.onDetails,
    required this.shareBoundaryKey,
  });

  @override
  Widget build(BuildContext context) {
    final topThree = [...leaders]..sort((a, b) => a.rank.compareTo(b.rank));
    final currentRank = rank;
    final hasRank = currentRank != null &&
        currentRank > 0 &&
        participantCount >= currentRank;

    return _LeaderboardShell(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              RepaintBoundary(
                key: shareBoundaryKey,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: _PodiumShareBrandMark(),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '🏆',
                              style: TextStyle(fontSize: 25, height: 1),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'BUGÜNÜN KÜRSÜSÜ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: Color(0xFFF5E6BC),
                                ),
                              ),
                            ),
                            const SizedBox(width: 36),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _DailyMiniPodium(
                          leaders: topThree,
                          totalQuestions: totalQuestions,
                        ),
                        const SizedBox(height: 12),
                        DailyMiniExamRankReveal(
                          rank: rank,
                          participantCount: participantCount,
                          leaders: topThree,
                          trend: trend,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  onPressed: hasRank ? onShare : null,
                  tooltip: 'Sıralamanı paylaş',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.ios_share_rounded,
                    size: 18,
                    color: AppTheme.champagneLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onDetails,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.champagneLight,
              minimumSize: const Size(double.infinity, 42),
            ),
            icon: const Icon(Icons.leaderboard_rounded, size: 18),
            label: const Text(
              'EN BAŞARILILAR',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardShell extends StatelessWidget {
  final Widget child;

  const _LeaderboardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8C878).withValues(alpha: 0.68),
          width: 1.15,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3D3218),
            Color(0xFF261F0F),
            Color(0xFF151107),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neonGold.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DailyMiniPodium extends StatelessWidget {
  final List<DailyMiniLeaderRow> leaders;
  final int totalQuestions;

  const _DailyMiniPodium({
    required this.leaders,
    required this.totalQuestions,
  });

  DailyMiniLeaderRow? _leaderAt(int place) {
    for (final leader in leaders) {
      if (leader.rank == place) return leader;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = AuthService.instance.user?.id;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _PodiumPlace(
            place: 2,
            leader: _leaderAt(2),
            totalQuestions: totalQuestions,
            isMe: _leaderAt(2)?.userId == myUserId,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _PodiumPlace(
            place: 1,
            leader: _leaderAt(1),
            totalQuestions: totalQuestions,
            isMe: _leaderAt(1)?.userId == myUserId,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _PodiumPlace(
            place: 3,
            leader: _leaderAt(3),
            totalQuestions: totalQuestions,
            isMe: _leaderAt(3)?.userId == myUserId,
          ),
        ),
      ],
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  final int place;
  final DailyMiniLeaderRow? leader;
  final int totalQuestions;
  final bool isMe;

  const _PodiumPlace({
    required this.place,
    required this.leader,
    required this.totalQuestions,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final first = place == 1;
    final color = switch (place) {
      1 => const Color(0xFFFFD76A),
      2 => const Color(0xFFD8DDE5),
      _ => const Color(0xFFD99A62),
    };
    final height = switch (place) { 1 => 84.0, 2 => 66.0, _ => 56.0 };
    final name = isMe
        ? 'Sen'
        : leader == null
            ? '—'
            : (leader!.displayName.isNotEmpty
                ? leader!.displayName
                : leader!.emailPrefix);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: first ? 38 : 32,
          height: first ? 38 : 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.16),
            border: Border.all(color: color.withValues(alpha: 0.8)),
          ),
          child: Text(
            first ? '👑' : '$place',
            style: TextStyle(
              fontSize: first ? 19 : 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isMe ? FontWeight.w900 : FontWeight.w700,
            color: isMe ? AppTheme.neonGold : Colors.white,
          ),
        ),
        const SizedBox(height: 5),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.34),
                  color.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(color: color.withValues(alpha: 0.46)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$place.',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: first ? 22 : 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                if (leader != null) ...[
                  Text(
                    '${leader!.correct}/$totalQuestions',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  if (leader!.durationSeconds > 0)
                    Text(
                      formatExamDuration(leader!.durationSeconds),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Kürsü paylaşım görseli — ortada siyah daire gölge + soluk HK logosu.
class _PodiumShareBrandMark extends StatelessWidget {
  const _PodiumShareBrandMark();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 176,
          height: 176,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 176,
                height: 176,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 42,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.38),
                      Colors.black.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                    stops: const [0.22, 0.68, 1.0],
                  ),
                ),
                alignment: Alignment.center,
                child: Opacity(
                  opacity: 0.18,
                  child: Image.asset(
                    BrandConstants.logoAsset,
                    width: 78,
                    height: 78,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      BrandConstants.watermarkAsset,
                      width: 96,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
