import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/models/daily_mini_exam_models.dart';
import 'package:kpss_akademi/utils/daily_mini_exam_logic.dart';

void main() {
  group('DailyMiniExamWindow', () {
    test('06:00–gece yarısı açık, gece yarısından 06:00’e kapalı', () {
      final open = DailyMiniExamWindow.from(DateTime(2026, 8, 13, 9, 12, 43));
      expect(open.isOpen, isTrue);
      expect(open.remainingLabel, '14:47:17 kaldı');

      final justOpen = DailyMiniExamWindow.from(DateTime(2026, 8, 13, 6, 0));
      expect(justOpen.isOpen, isTrue);

      final stillClosed = DailyMiniExamWindow.from(DateTime(2026, 8, 13, 5, 59));
      expect(stillClosed.isOpen, isFalse);

      final closed = DailyMiniExamWindow.from(DateTime(2026, 8, 13, 2, 0));
      expect(closed.isOpen, isFalse);
      expect(closed.remaining.inHours, 4);
    });
  });

  group('frosted email', () {
    test('@ öncesinde ilk 3 harfi ayırır', () {
      final parts = splitFrostedEmail('ahmet@gmail.com');
      expect(parts.prefix, 'ahm');
      expect(parts.rest, '•••@gmail.com');
    });
  });

  group('exam duration', () {
    test('dakika ve saniye formatlar', () {
      expect(formatExamDuration(484), '8 dk 04 sn');
      expect(formatExamDuration(45), '45 sn');
    });
  });

  group('congratulations', () {
    test('sıralama cümlesini Türkçe binlik ayracıyla kurar', () {
      final text = congratulationsMessage(
        total: 20,
        correct: 16,
        wrong: 4,
        rank: 312,
        participantCount: 5340,
      );
      expect(
        text,
        'Tebrikler! 20 Soruda 16 Doğru, 4 Yanlış yaptın. '
        'Bugün bu testi çözen 5.340 kişi arasında 312. oldun!',
      );
    });
  });

  group('rank badge', () {
    test('rozet satırını Türkçe binlik ayracıyla kurar', () {
      expect(
        formatRankBadgeLine(participantCount: 5340, rank: 312),
        'Bugünkü Sıralaman: 5.340 Kişi Arasından 312.',
      );
      expect(
        formatRankBadgeLine(participantCount: 7200, rank: 450),
        'Bugünkü Sıralaman: 7.200 Kişi Arasından 450.',
      );
    });

    test('paylaşım metnini marka ve skorla kurar', () {
      final text = buildDailyMiniShareText(
        rank: 312,
        participantCount: 5340,
        correct: 16,
        total: 20,
      );
      expect(text, contains('5.340 kişi arasından 312.'));
      expect(text, contains('16/20 doğru'));
      expect(text, contains('Hedef Kamu'));
    });
  });

  group('picker', () {
    test('LCG shuffle kararlıdır', () {
      final items = List.generate(10, (i) => 'q$i');
      expect(lcgShuffle(items, 42), lcgShuffle(items, 42));
      expect(lcgShuffle(items, 42), isNot(lcgShuffle(items, 43)));
    });

    test('havuzlardan 5+5+5+5 alır', () {
      List<String> pool(String prefix) =>
          List.generate(8, (i) => '${prefix}_$i');
      final ids = pickLocalQuestionIds(
        examDate: DateTime(2026, 8, 13),
        kpssType: 'lisans',
        tarihIds: pool('t'),
        cografyaIds: pool('c'),
        vatandaslikIds: pool('v'),
        turkceIds: pool('tr'),
      );
      expect(ids, hasLength(20));
      expect(ids.toSet(), hasLength(20));
      expect(ids.where((id) => id.startsWith('t_')), hasLength(5));
      expect(ids.where((id) => id.startsWith('c_')), hasLength(5));
      expect(ids.where((id) => id.startsWith('v_')), hasLength(5));
      expect(ids.where((id) => id.startsWith('tr_')), hasLength(5));
    });
  });

  group('attempt ranking', () {
    test('boş deneme sıralamaya girmez', () {
      const empty = DailyMiniAttempt(
        correct: 0,
        wrong: 0,
        blank: 20,
        total: 20,
        durationSeconds: 5,
      );
      const answered = DailyMiniAttempt(
        correct: 0,
        wrong: 1,
        blank: 19,
        total: 20,
        durationSeconds: 40,
      );
      expect(empty.countsTowardRanking, isFalse);
      expect(answered.countsTowardRanking, isTrue);
    });
  });
}
