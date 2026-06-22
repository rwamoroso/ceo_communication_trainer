import 'package:ceo_communication_trainer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('app starts on sign-in', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: ExecutiveTrainerApp()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsOneWidget);
    expect(
      find.textContaining('Train the way executives communicate'),
      findsOneWidget,
    );
  });
}
