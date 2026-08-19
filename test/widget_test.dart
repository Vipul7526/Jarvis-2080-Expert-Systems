import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_assistant/main.dart';

void main() {
  testWidgets('onboarding boots with the holographic core',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onCompleted: () {})),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(HolographicCore), findsOneWidget);
    expect(find.text('J.A.R.V.I.S. 2080'), findsOneWidget);
  });

  testWidgets('tab lock page explains the real extension boundary',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TabLockPage()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('TAB LOCK'), findsOneWidget);
    expect(find.text('CHROME EXTENSION REQUIRED'), findsOneWidget);
    expect(find.textContaining('Android cannot block Chrome pages'),
        findsOneWidget);
  });
}
