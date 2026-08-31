import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/utils/option_percentage_utils.dart';

void main() {
  test('first answer shows 100% on selected option', () {
    final out = bumpOptionDistribution(
      base: null,
      solvedCount: 0,
      selectedKey: 'C',
      optionKeys: const ['B', 'C', 'D', 'E'],
    );
    expect(out['C'], 100.0);
    expect(out['B'], 0.0);
  });

  test('bumps selected option from historical distribution', () {
    final out = bumpOptionDistribution(
      base: const {'A': 0, 'B': 100, 'C': 0, 'D': 0, 'E': 0},
      solvedCount: 1,
      selectedKey: 'C',
      optionKeys: const ['B', 'C', 'D', 'E'],
    );
    expect(out['B'], 50.0);
    expect(out['C'], 50.0);
    expect(out['D'], 0.0);
  });
}
