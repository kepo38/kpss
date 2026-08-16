import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/utils/solution_preview.dart';

void main() {
  test('shows first two sentences in preview', () {
    const text =
        'İlk cümle burada. İkinci cümle devam eder. Üçüncü cümle kilitli kalır.';
    final parts = splitSolutionPreview(text);

    expect(parts.preview, contains('İlk cümle'));
    expect(parts.preview, contains('İkinci cümle'));
    expect(parts.remainder, contains('Üçüncü cümle'));
    expect(parts.hasLockedRemainder, isTrue);
  });

  test('short solution has no locked remainder', () {
    const text = 'Kısa çözüm.';
    final parts = splitSolutionPreview(text);

    expect(parts.hasLockedRemainder, isFalse);
    expect(parts.preview, text);
  });

  test('long single sentence is truncated for preview', () {
    final text = '${'A' * 40} ${'B' * 200}';
    final parts = splitSolutionPreview(text, maxPreviewChars: 100);

    expect(parts.preview.length, lessThan(text.length));
    expect(parts.hasLockedRemainder, isTrue);
    expect(parts.remainder, isNotEmpty);
  });
}
