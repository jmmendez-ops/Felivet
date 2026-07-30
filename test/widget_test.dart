// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:feline_detector/app/app.dart';

void main() {
  testWidgets('app boots on splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FeliVetApp());

    expect(find.text('FeliVet Insights'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.text('FeliVet Insight'), findsWidgets);
  });
}
