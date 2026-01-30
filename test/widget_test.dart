import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakhi/main.dart';

void main() {
  testWidgets('App starts and shows home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SakhiApp());

    // Verify that the app title is displayed
    expect(find.text('SAKHI'), findsOneWidget);

    // Verify that the welcome message is displayed
    expect(find.text('Your Safety Companion'), findsOneWidget);

    // Verify that the emergency button is present
    expect(find.text('EMERGENCY'), findsOneWidget);
  });

  testWidgets('Navigation to Emergency Contacts works',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SakhiApp());

    // Find and tap the Emergency Contacts card
    await tester.tap(find.text('Emergency Contacts'));
    await tester.pumpAndSettle();

    // Verify that we navigated to the Emergency Contacts screen
    expect(find.text('No emergency contacts added'), findsOneWidget);
  });

  testWidgets('Navigation to Safe Routes works', (WidgetTester tester) async {
    await tester.pumpWidget(const SakhiApp());

    // Find and tap the Safe Routes card
    await tester.tap(find.text('Safe Routes'));
    await tester.pumpAndSettle();

    // Verify that we navigated to the Safe Routes screen
    expect(find.text('Safe Routes Feature'), findsOneWidget);
  });
}
