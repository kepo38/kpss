import 'package:flutter_test/flutter_test.dart';

import 'package:kpss_akademi/widgets/formatted_text.dart';

void main() {
  test('plain prose II. Kök Türk must not gain line break before dynasty reference', () {
    const stem =
        "I. Kök Türk Devleti'nin yıkılmasının ardından Türk boyları yaklaşık 50 yıl Çin esaretinde yaşamıştır. "
        'Bu süreçte bağımsızlık ateşini yakarak Türk tarihinin ilk milli ayaklanmasını başlatan ancak başarısız olan kahraman ile '
        "Çin esaretine son verip II. Kök Türk (Kutluk) Devleti'ni kurarak hükümdar ikilisi aşağıdakilerin hangisinde doğru verilmiştir?";
    final prepared = FormattedText.prepareExamJustifyText(stem);
    expect(prepared.contains('\nII.'), isFalse, reason: 'stem justify: $prepared');
    expect(prepared.contains('verip II.'), isTrue);

    final restored = FormattedText.restoreCollapsedBreaks(stem);
    expect(restored.contains('\nII.'), isFalse, reason: 'restore: $restored');

    final solution = FormattedText.prepareSolutionText(
      '**1. Aşama: Test**\n$stem',
    );
    expect(solution.contains('\nII.'), isFalse, reason: 'solution: $solution');
  });

  test('premise list with colons still splits roman sections', () {
    const premises =
        'I. Birinci öncül metni: açıklama devam eder. '
        'II. İkinci öncül metni: ikinci açıklama burada.';
    final restored = FormattedText.restoreCollapsedBreaks(premises);
    expect(restored, contains('\nII.'));
  });
}
