// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sakhi/main.dart';

void main() {
  testWidgets('App loads with splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SakhiApp());
    await tester.pumpAndSettle();

    // Verify that the splash screen displays the app branding
    expect(find.text('SAKHI'), findsOneWidget);
    expect(find.text('Your Trusted Companion'), findsOneWidget);
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
  });
}
