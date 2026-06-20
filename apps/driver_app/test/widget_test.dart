// Basic smoke test for the Rickbo driver app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke: a bare MaterialApp pumps', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Rickbo Driver'))),
    );
    expect(find.text('Rickbo Driver'), findsOneWidget);
  });
}