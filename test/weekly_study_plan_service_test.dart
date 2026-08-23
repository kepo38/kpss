import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/services/weekly_study_plan_service.dart';
import 'package:kpss_akademi/widgets/countdown_widget.dart';

void main() {
  test('weekly plan has today free and future days', () {
    final plan = WeeklyStudyPlanService.instance.buildPlan(KpssType.lisans);
    expect(plan.length, 7);
    expect(plan.first.isToday, isTrue);
    expect(plan.first.dayLabel, 'Bugün');
    expect(plan[1].isToday, isFalse);
    expect(plan[1].dayLabel, 'Yarın');
  });
}
