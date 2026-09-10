import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/widgets/formatted_text.dart';

const _sample = r'''Unutulan mutlak değer çizgisini (\(\vert{}\)) şıklardaki sayıların sağından başlayarak tek tek deneyelim ve işlemin sonucunun 3 çıkıp çıkmadığını kontrol edelim:A) 3'ün sağında olsaydı:\(\vert{}-3\vert{} + 4 - 5 + 6 - 7 = 3 + 4 - 5 + 6 - 7 = 1 \neq 3\) ❌B) 4'ün sağında olsaydı:\(\vert{}-3 + 4\vert{} - 5 + 6 - 7 = \vert{}1\vert{} - 5 + 6 - 7 = 1 - 5 + 6 - 7 = -5 \neq 3\) ❌C) 5'in sağında olsaydı:\(\vert{}-3 + 4 - 5\vert{} + 6 - 7\)İlk önce mutlak değerin içini hesaplayalım: \(-3 + 4 - 5 = -4\)Now: \(\vert{}-4\vert{} + 6 - 7 = 4 + 6 - 7 = 10 - 7 = \mathbf{3}\)  Doğru!  ✅''';

const _abSample = r'''Adım Adım Çözüm:İki basamaklı sayımız \(ab\) olsun. Soruda verilen şartlar şunlardır:Rakamlar sıfırdan farklı (\(a \neq 0, b \neq 0\))Rakamlar birbirinden farklı (\(a \neq b\))Son maddede "onlar basamağındaki rakamın birler basamağındaki rakama oranı" bir doğal sayı belirtmektedir. Yani \(\frac{a}{b}\) bir tam sayıdır (\(a\), \(b\)'nin katıdır).Elde edilen 5 sayıdan 4'ü çift, 1'i tek sayıdır.Kağıda yazılan 5 sayıyı formülleştirelim:Kendisi: \(10a + b\)Rakamları toplamı: \(a + b\)Rakamları çarpımı: \(a \times b\)Rakamları farkının mutlak değeri: \(\vert{}a - b\vert{}\)Rakamların oranı: \(\frac{a}{b}\)1. Tek/Çift Analizi Yaparak Sayıyı Bulma:\(a \times b\) (Rakamlar Çarpımı): Elde edilen 5 sayıdan sadece 1 tanesi tek olduğuna göre, bu çarpımın çift olması şarttır.Şimdi \(\frac{a}{b}\) oranının bir doğal sayı olmasını ve rakamların durumlarını inceleyelim. Sayımızın \(62\) olduğunu varsayıp test edelim (\(a=6, b=2\)):Kendisi: \(62\) (Çift)Rakamları toplamı: \(6 + 2 = 8\) (Çift)Rakamları çarpımı: \(6 \times 2 = 12\) (Çift)Rakamları farkı: \(\vert{}6 - 2\vert{} = 4\) (Çift)Rakamları oranı: \(\frac{6}{2} = 3\) (Tek)Görüldüğü gibi \(62\) sayısı için elde edilen değerlerden 4 tanesi çift (62, 8, 12, 4) ve tam olarak 1 tanesi tek (3) çıkmaktadır.2. Kağıttaki Sayıların Toplamını Hesaplama:Bulduğumuz bu 5 doğal sayıyı toplayalım:\(62 + 8 + 12 + 4 + 3 = \mathbf{105}\)''';

const _xyzSample = r'''1. Adım: Toplama İşlemini Alt Alta Yazalım\(\begin{array}{r@{\quad }c@{\quad }c@{\quad }c}5&2&A&\\ +&B&4&3\\ \hline X&Y&Z&\end{array}\)Elde edilen \(XYZ\) üç basamaklı sayısının tüm rakamları birbirinden farklı tek sayılar (\(1, 3, 5, 7, 9\)) olmak zorundadır.2. Adım: Onlar Basamağını İnceleyelimOnlar basamağındaki işlem: \(2 + 4 = 6\)Sonucun tek sayı olması gerektiği için, birler basamağından onlar basamağına kesinlikle 1 elde gelmiştir.Bu durumda onlar basamağının yeni sonucu: \(2 + 4 + 1 = \mathbf{7}\) olur.Böylece ortadaki rakamı bulduk: \(Y = 7\).3. Adım: Birler Basamağından Elde Gelmesini SağlayalımBirler basamağındaki işlem: \(A + 3\)5. Adım: Sonuç ve KontrolSayıları yerine yazalım: \(528 + 443 = \mathbf{971}\)Doğru Seçenek: D''';

void main() {
  group('Google Docs mutlak değer çözümü', () {
    test('vert{} mutlak değer çubuklarını düzeltir', () {
      expect(
        FormattedText.repairGoogleDocsVertBars(r'\vert{}-3\vert{}'),
        r'\lvert -3 \rvert',
      );
      expect(
        FormattedText.repairGoogleDocsVertBars(r'\vert{}1\vert{}'),
        r'\lvert 1 \rvert',
      );
    });

    test('yapışık A/B/C satırlarını ayırır', () {
      final laidOut = FormattedText.prepareSolutionText(_sample);
      expect(laidOut, contains('A) 3'));
      expect(laidOut, contains('B) 4'));
      expect(laidOut, contains('C) 5'));
      expect(laidOut, contains('❌'));
      expect(laidOut, contains('✅'));
      expect(laidOut, contains(r'\lvert'));
      expect(laidOut, contains(r'\neq'));
      expect(laidOut, contains(r'\mathbf{3}'));
      expect(laidOut, contains('İlk önce mutlak değerin'));
    });

    test('giriş paragrafında mutlak değer sembolü görünür', () {
      final laidOut = FormattedText.prepareSolutionText(_sample);
      expect(laidOut, contains('|'));
      expect(laidOut, contains('Unutulan mutlak değer'));
    });
  });

  group('Google Docs ab iki basamaklı çözümü', () {
    test('yapışık formül listesi ve numaralı bölümleri ayırır', () {
      final laidOut = FormattedText.prepareSolutionText(_abSample);
      expect(laidOut, contains('**Adım Adım Çözüm:**'));
      expect(laidOut, contains('- Rakamlar sıfırdan farklı'));
      expect(laidOut, contains('- Kendisi:'));
      expect(laidOut, contains('- Rakamları toplamı:'));
      expect(laidOut, contains('- Rakamları çarpımı:'));
      expect(laidOut, contains(r'\lvert'));
      expect(laidOut, contains('**1. Tek/Çift Analizi Yaparak Sayıyı Bulma:**'));
      expect(laidOut, contains('**2. Kağıttaki Sayıların Toplamını Hesaplama:**'));
      expect(laidOut, contains(r'\mathbf{105}'));
      expect(laidOut, contains('(Tek)'));
      expect(laidOut, contains('Görüldüğü gibi'));
      expect(laidOut.indexOf('(Tek)'), lessThan(laidOut.indexOf('Görüldüğü gibi')));
    });
  });

  group('Enter ile bölünmüş inline \$ math', () {
    test('mergeSplitInlineDollarMath birleştirir', () {
      expect(
        FormattedText.mergeSplitInlineDollarMath(r'$Y' '\n' r'= 7$'),
        r'$Y = 7$',
      );
      final closedBeforeBreak = 'Sonuç: ' r'$6$' '\n' 'Sonucun';
      expect(
        FormattedText.mergeSplitInlineDollarMath(closedBeforeBreak),
        closedBeforeBreak,
      );
      final display = r'Blok $$X' '\n' r'+ Y$$ devam';
      expect(
        FormattedText.mergeSplitInlineDollarMath(display),
        display,
      );
    });

    test('prepareSolutionText bölünmüş harf formülünü düzeltir', () {
      const splitY = r'1. Adım: Ortadaki rakamı bulduk: $Y' '\n' r'= 7$.';
      final laidOut = FormattedText.prepareSolutionText(splitY);
      expect(laidOut, contains(r'$Y = 7$'));
      expect(laidOut, isNot(contains(r'\n= 7$')));
    });
  });

  group('Google Docs XYZ toplama çözümü', () {
    test('array formülü ve adım başlıklarını ayırır', () {
      final laidOut = FormattedText.prepareSolutionText(_xyzSample);
      expect(laidOut, contains('**1. Adım: Toplama İşlemini Alt Alta Yazalım**'));
      expect(laidOut, contains('**2. Adım: Onlar Basamağını İnceleyelim**'));
      expect(laidOut, contains('**3. Adım: Birler Basamağından Elde Gelmesini Sağlayalım**'));
      expect(laidOut, contains(r'\begin{array}'));
      expect(laidOut, contains(r'$$'));
      expect(laidOut, contains('Elde edilen'));
      expect(laidOut, contains('Sonucun tek'));
      expect(laidOut, contains(r'\mathbf{971}'));
    });
  });
}
