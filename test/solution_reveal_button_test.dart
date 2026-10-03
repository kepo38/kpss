import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/widgets/solution_reveal_button.dart';

class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool enabled = false;
  int token = 0;

  void select() => setState(() {
        enabled = true;
        token++;
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 120,
            child: SolutionRevealButton(
              enabled: enabled,
              showingSolution: false,
              style: OutlinedButton.styleFrom(),
              onPressed: enabled ? () {} : null,
              pulseToken: token,
            ),
          ),
        ),
      ),
    );
  }
}

double _scaleOf(WidgetTester tester) {
  final t = tester.widget<Transform>(
    find.descendant(
      of: find.byType(SolutionRevealButton),
      matching: find.byType(Transform),
    ),
  );
  return t.transform.getMaxScaleOnAxis();
}

void main() {
  Future<double> peakScaleAfterSelect(WidgetTester tester) async {
    await tester.pumpWidget(const _Host());
    final state = tester.state<_HostState>(find.byType(_Host));
    expect(_scaleOf(tester), 1.0);

    state.select();
    var peak = 1.0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final s = _scaleOf(tester);
      if (s > peak) peak = s;
    }
    return peak;
  }

  testWidgets('şık seçilince buton belirgin biçimde büyür (pulse)', (
    tester,
  ) async {
    final peak = await peakScaleAfterSelect(tester);
    expect(peak, greaterThan(1.06));
    // Sonunda normal boyuta döner.
    await tester.pump(const Duration(seconds: 3));
    expect(_scaleOf(tester), closeTo(1.0, 0.001));
  });

  testWidgets('sistem animasyonları kapalıyken de pulse görünür', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final peak = await peakScaleAfterSelect(tester);
    expect(peak, greaterThan(1.06));
  });

  testWidgets('pasifken animasyon oynamaz', (tester) async {
    await tester.pumpWidget(const _Host());
    await tester.pump(const Duration(milliseconds: 300));
    expect(_scaleOf(tester), 1.0);
  });
}