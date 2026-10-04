import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:odysseygame/main.dart';

void main() {
  testWidgets('App boots into the loading screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SnowfallApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
