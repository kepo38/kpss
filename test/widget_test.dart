import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/main.dart';

void main() {
  testWidgets('Hedef Kamu uygulaması açılır', (WidgetTester tester) async {
    await tester.pumpWidget(const KpssOdakApp());
    await tester.pump();
    expect(find.byType(KpssOdakApp), findsOneWidget);
  });
}
