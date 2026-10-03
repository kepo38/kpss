import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/services/wrong_notebook_capacity.dart';

void main() {
  group('WrongNotebookCapacity.capNewIds', () {
    test('allows all new ids for premium users', () {
      final result = WrongNotebookCapacity.capNewIds(
        isPremium: true,
        archivedCount: 29,
        freeLimit: 30,
        candidateIds: ['a', 'b', 'c'],
        existingIds: {'x'},
      );
      expect(result.allowed, ['a', 'b', 'c']);
      expect(result.skipped, 0);
    });

    test('caps new ids for free users at remaining slots', () {
      final result = WrongNotebookCapacity.capNewIds(
        isPremium: false,
        archivedCount: 28,
        freeLimit: 30,
        candidateIds: ['a', 'b', 'c'],
        existingIds: const {},
      );
      expect(result.allowed, ['a', 'b']);
      expect(result.skipped, 1);
    });

    test('blocks all new ids when archive is full', () {
      final result = WrongNotebookCapacity.capNewIds(
        isPremium: false,
        archivedCount: 30,
        freeLimit: 30,
        candidateIds: ['a'],
        existingIds: const {},
      );
      expect(result.allowed, isEmpty);
      expect(result.skipped, 1);
    });

    test('ignores ids already in archive', () {
      final result = WrongNotebookCapacity.capNewIds(
        isPremium: false,
        archivedCount: 30,
        freeLimit: 30,
        candidateIds: ['a', 'b'],
        existingIds: {'a', 'b'},
      );
      expect(result.allowed, isEmpty);
      expect(result.skipped, 0);
    });
  });
}
