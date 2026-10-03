import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/widgets/formatted_text.dart';

void main() {
  final fixturePath = 'backend/content/fixtures/rich_text_parity.json';
  final file = File(fixturePath);
  if (!file.existsSync()) {
    throw StateError('Parity fixture missing: $fixturePath');
  }
  final data = jsonDecode(file.readAsStringSync(encoding: utf8)) as Map;
  final cases = data['cases'] as List<dynamic>;
  if (cases.isEmpty) {
    throw StateError('Parity fixture has no cases');
  }

  group('stored display prep is idempotent on Python expected', () {
    for (final raw in cases) {
      final caseMap = raw as Map<String, dynamic>;
      final id = caseMap['id'] as String;
      final field = (caseMap['field'] as String?) ?? 'solution';
      final expected = caseMap['expected'] as String?;

      test(id, () {
        expect(expected, isNotNull, reason: 'Run regenerate_rich_text_parity');
        if (field == 'solution') {
          expect(
            FormattedText.prepareStoredSolutionText(expected!),
            expected,
          );
        } else {
          expect(
            FormattedText.prepareStoredExamDisplayText(expected!),
            expected,
          );
        }
      });
    }
  });

  test('legacy paste pipeline transforms raw input; stored path preserves expected', () {
    final caseMap = cases.firstWhere(
      (c) => (c as Map)['id'] == 'colon_premise_roman',
    ) as Map<String, dynamic>;
    final input = caseMap['input'] as String;
    final expected = caseMap['expected'] as String;
    expect(FormattedText.prepareStoredSolutionText(expected), expected);
    expect(FormattedText.prepareSolutionText(input), isNot(equals(input)));
    expect(FormattedText.prepareSolutionText(input), isNot(equals(expected)));
  });
}
