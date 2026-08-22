import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openAddExam() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddExamSheet(),
    );
    if (!mounted) return;
    if (saved == true) {
      setState(() {});
      NotificationService.instance.refreshWeeklySummaryContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final embedded = widget.embedded;
    return Scaffold(
      backgroundColor: embedded ? AppTheme.page(context) : null,
      appBar: AppBar(
        // Shell already owns the status inset; avoid double top gap.
        primary: !embedded,
        backgroundColor: embedded ? AppTheme.page(context) : null,
        foregroundColor: embedded ? AppTheme.ink : null,
        leading: embedded ? null : const AppBackButton(),
        automaticallyImplyLeading: !embedded,
        centerTitle: embedded,
        title: embedded ? const Text('Denemeler') : const Text('Deneme İstatistiklerim'),
        titleSpacing: embedded ? 0 : null,
        toolbarHeight: embedded ? 52 : null,
        bottom: TabBar(
          controller: _tabController,
          labelColor: embedded ? AppTheme.ink : null,
          unselectedLabelColor:
              embedded ? AppTheme.slate.withValues(alpha: 0.55) : null,
          indicatorColor: embedded ? AppTheme.champagne : null,
          tabs: const [
            Tab(text: 'Genel Bakış'),
            Tab(text: 'Yayın Evleri'),
            Tab(text: 'Denemeler'),
          ],
        ),
        actions: const [],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExam,
        backgroundColor: embedded ? AppTheme.champagne : null,
        foregroundColor: embedded ? AppTheme.ink : null,
        icon: const Icon(Icons.add),
        label: const Text('Deneme Ekle'),
      ),
    );
  }
}
