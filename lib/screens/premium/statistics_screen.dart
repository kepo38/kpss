import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../models/exam_insight.dart';
import '../../widgets/exam_insight_dialog.dart';
import '../../widgets/exam_premium_shell.dart';
import '../../widgets/puan_hesaplama_button.dart';
import '../../widgets/statistics_exams_tab.dart';
import '../../widgets/statistics_overview_tab.dart';
import '../../widgets/statistics_publishers_tab.dart';
import 'add_exam_sheet.dart';

/// Premium deneme analiz merkezi — grafikler ve ayrı sekme bileşenleri.
class StatisticsScreen extends StatefulWidget {
  final bool embedded;

  const StatisticsScreen({super.key, this.embedded = false});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    (Icons.insights_outlined, 'Genel Bakış'),
    (Icons.storefront_outlined, 'Yayın Evleri'),
    (Icons.assignment_outlined, 'Denemeler'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 2);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openAddExam() async {
    final result = await showModalBottomSheet<ExamSaveResult?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddExamSheet(),
    );
    if (!mounted || result == null) return;
    setState(() {});
    if (result.insight != null) {
      await showExamInsightDialog(context, result.insight!);
    }
    NotificationService.instance.refreshWeeklySummaryContent();
  }

  @override
  Widget build(BuildContext context) {
    final embedded = widget.embedded;
    return Scaffold(
      backgroundColor: embedded ? AppTheme.page(context) : null,
      appBar: embedded
          ? null
          : AppBar(
              backgroundColor: AppTheme.page(context),
              foregroundColor: AppTheme.onPage(context),
              leading: const AppBackButton(),
              centerTitle: true,
              title: const Text(
                'Deneme İstatistiklerim',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      body: ExamPremiumBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, embedded ? 4 : 8, 20, 0),
              child: Column(
                children: [
                  const PuanHesaplamaButton(),
                  const SizedBox(height: 14),
                  _ExamSegmentTabs(
                    tabs: _tabs,
                    selectedIndex: _tabController.index,
                    onChanged: (i) {
                      _tabController.animateTo(i);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  StatisticsOverviewTab(onRefresh: () => setState(() {})),
                  StatisticsPublishersTab(onFilter: () => setState(() {})),
                  StatisticsExamsTab(onRefresh: () => setState(() {})),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _PremiumAddExamFab(onPressed: _openAddExam),
    );
  }
}

class _ExamSegmentTabs extends StatelessWidget {
  final List<(IconData, String)> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _ExamSegmentTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.ink.withValues(alpha: 0.06),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: _SegmentTab(
                  icon: tabs[i].$1,
                  label: tabs[i].$2,
                  selected: selectedIndex == i,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A2438),
                      Color(0xFF121A2A),
                    ],
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.champagne.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? AppTheme.champagneLight
                    : AppTheme.mutedOnPage(context),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: selected ? 0.2 : 0,
                  color: selected
                      ? Colors.white
                      : AppTheme.mutedOnPage(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumAddExamFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _PremiumAddExamFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFE2C998),
                Color(0xFFC9A86C),
                Color(0xFFB8944A),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.champagne.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppTheme.ink.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: AppTheme.ink, size: 22),
                SizedBox(width: 8),
                Text(
                  'Deneme Ekle',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
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
