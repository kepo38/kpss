import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/services/smart_review_service.dart';

void main() {
  final now = DateTime(2026, 8, 10, 9);

  test('day key is local calendar date', () {
    expect(SmartReviewLogic.dayKey(now), '2026-08-10');
  });

  test('wrong answers reset interval to one day', () {
    final schedule = SmartReviewLogic.scheduleAfterWrong(
      previous: ReviewSchedule(
        dueAt: DateTime(2026, 8, 1),
        intervalDays: 8,
      ),
      now: now,
    );
    expect(schedule.intervalDays, 1);
    expect(schedule.dueAt, DateTime(2026, 8, 11, 9));
  });

  test('correct answers double interval up to 30 days', () {
    final first = SmartReviewLogic.scheduleAfterCorrect(
      previous: null,
      now: now,
    );
    expect(first.intervalDays, 2);

    final grown = SmartReviewLogic.scheduleAfterCorrect(
      previous: ReviewSchedule(
        dueAt: DateTime(2026, 8, 1),
        intervalDays: 16,
      ),
      now: now,
    );
    expect(grown.intervalDays, 30);
  });

  test('selection prioritizes wrong ids then weak topics up to target', () {
    final selected = SmartReviewLogic.selectQuestionIds(
      wrongQuestionIds: ['w1', 'w2', 'w3'],
      weakTopicQuestionIds: ['a1', 'a2', 'a3', 'a4', 'w2'],
      schedules: const {},
      now: now,
      target: 5,
      daySeed: 42,
    );
    expect(selected.length, 5);
    expect(selected.toSet().intersection({'w1', 'w2', 'w3'}).length, 3);
    expect(selected.where((id) => id.startsWith('a')).length, 2);
  });

  test('due wrong questions come before not-due ones', () {
    final selected = SmartReviewLogic.selectQuestionIds(
      wrongQuestionIds: ['later', 'due'],
      weakTopicQuestionIds: const [],
      schedules: {
        'later': ReviewSchedule(
          dueAt: now.add(const Duration(days: 3)),
          intervalDays: 3,
        ),
        'due': ReviewSchedule(
          dueAt: now.subtract(const Duration(hours: 1)),
          intervalDays: 1,
        ),
      },
      now: now,
      target: 2,
      daySeed: 7,
    );
    expect(selected.first, 'due');
  });

  test('daily target constant is 15', () {
    expect(SmartReviewService.dailyTarget, 15);
  });

  test('selection never invents ids outside wrongs+weak pool', () {
    final pool = {'w1', 'w2', 'a1'};
    final selected = SmartReviewLogic.selectQuestionIds(
      wrongQuestionIds: ['w1', 'w2'],
      weakTopicQuestionIds: ['a1'],
      schedules: const {},
      now: now,
      target: 15,
      daySeed: 99,
    );
    expect(selected.length, 3);
    expect(selected.toSet().difference(pool), isEmpty);
  });

  // Havuz hedeften küçükse select hedefe pad etmez; mevcut boyutta durur.
  test('selection stops at available pool size when pool < target', () {
    final selected = SmartReviewLogic.selectQuestionIds(
      wrongQuestionIds: ['w1'],
      weakTopicQuestionIds: ['a1', 'a2'],
      schedules: const {},
      now: now,
      target: SmartReviewService.dailyTarget,
      daySeed: 1,
    );
    expect(selected.length, lessThan(SmartReviewService.dailyTarget));
    expect(selected.length, 3);
    expect(selected.toSet(), {'w1', 'a1', 'a2'});
  });
}
