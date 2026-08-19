import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_assistant/main.dart';

void main() {
  testWidgets('JARVIS app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const JarvisApp());
    await tester.pump();
    expect(find.byType(JarvisApp), findsOneWidget);
  });
}
