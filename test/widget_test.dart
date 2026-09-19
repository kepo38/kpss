import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/main.dart';
import 'package:kpss_akademi/widgets/boot_splash_screen.dart';

void main() {
  testWidgets('Hedef Kamu uygulaması açılır', (WidgetTester tester) async {
    await tester.pumpWidget(const KpssOdakApp());
    await tester.pump();
    expect(find.byType(KpssOdakApp), findsOneWidget);
    // Minimum launch splash süresini test içinde tüket.
    await tester.pump(kAssignmentSplashDuration);
    await tester.pump();
  });
}
