import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/utils/app_version_utils.dart';

void main() {
  test('compareAppVersions orders semver parts', () {
    expect(compareAppVersions('1.0.0', '1.0.1'), -1);
    expect(compareAppVersions('1.0.2', '1.0.1'), 1);
    expect(compareAppVersions('1.0.1', '1.0.1'), 0);
    expect(compareAppVersions('1.0.1+3', '1.0.2'), -1);
    expect(compareAppVersions('2.0.0', '1.9.9'), 1);
  });

  test('isAppVersionOlder ignores empty recommended', () {
    expect(isAppVersionOlder('1.0.0', ''), isFalse);
    expect(isAppVersionOlder('1.0.0', '1.0.1'), isTrue);
    expect(isAppVersionOlder('1.0.2', '1.0.1'), isFalse);
  });
}
