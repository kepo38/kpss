import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/layout/app_breakpoints.dart';

void main() {
  group('AppBreakpoints grid helpers', () {
    test('subjectGridAspectRatio widens tiles for 3 columns', () {
      expect(
        AppBreakpoints.subjectGridAspectRatio(2),
        greaterThan(AppBreakpoints.subjectGridAspectRatio(3)),
      );
    });

    test('content max width constants are ordered', () {
      expect(AppBreakpoints.webFrameMaxWidth, lessThan(AppBreakpoints.tabletContentMaxWidth));
      expect(AppBreakpoints.tabletContentMaxWidth, lessThan(AppBreakpoints.wideContentMaxWidth));
    });
  });
}
