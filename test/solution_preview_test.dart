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

  test('does not split sentences on periods inside latex', () {
    const text =
        r'Pay: $\frac{1}{5} + 2 \cdot \frac{1}{4}$. Payda ayrı hesaplanır.';
    final parts = splitSolutionPreview(text, maxPreviewChars: 400);

    expect(
      parts.preview.contains(r'$\frac{1}{5} + 2 \cdot \frac{1}{4}$'),
      isTrue,
    );
  });

  test('does not leave unclosed latex in preview', () {
    const text =
        r'1. Pay Kısmının Hesaplanması. Pay Toplamı: $\frac{1}{5} + 2 \cdot \frac{1}{4} = \frac{7}{10}$. Payda devam eder ve kilitlenir.';
    final parts = splitSolutionPreview(
      text,
      maxSentences: 2,
      maxPreviewChars: 70,
    );

    final dollars = r'$'.allMatches(parts.preview).length;
    expect(dollars.isEven, isTrue, reason: parts.preview);
  });
}
