import 'package:flutter_test/flutter_test.dart';

import 'package:kpss_akademi/widgets/question_stem_content.dart';

void main() {
  test('hasInlineFigure detects [ŞEKİL]', () {
    expect(QuestionStemContent.hasInlineFigure('Metin [ŞEKİL] devam'), isTrue);
    expect(QuestionStemContent.hasInlineFigure('Sadece metin'), isFalse);
  });

  test('previewText strips [ŞEKİL] and [HARITA]', () {
    final text = QuestionStemContent.previewText(
      'Üst\n\n[HARITA]\n\norta\n\n[ŞEKİL]\n\nalt',
    );
    expect(text.contains('[ŞEKİL]'), isFalse);
    expect(text.contains('[HARITA]'), isFalse);
    expect(text.contains('Üst'), isTrue);
    expect(text.contains('orta'), isTrue);
    expect(text.contains('alt'), isTrue);
  });
}
