// Minimal smoke tests. The app itself requires Firebase to be initialized,
// which is not available in the widget-test environment, so these cover only
// framework-level behavior.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp can be pumped', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('NNI')),
      ),
    );
    expect(find.text('NNI'), findsOneWidget);
  });
}
