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

  testWidgets('simulation dashboard is clearly marked as prank-only',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HackingDashboardPage()));
    await tester.pump();
    expect(find.text('SIMULATION DECK'), findsOneWidget);
    expect(find.textContaining('PRANK MODE'), findsOneWidget);
    expect(find.textContaining('does not hack'), findsOneWidget);
    expect(find.byType(HackingDashboardPage), findsOneWidget);
  });
}
