import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snowfall_odyssey/screens/menu_screen.dart';

void main() {
  testWidgets('Menu renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MenuScreen()));
    // Only verifying that the widget tree builds; the long gray-flow
    // boot pipeline is integration-tested, not unit-tested.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
