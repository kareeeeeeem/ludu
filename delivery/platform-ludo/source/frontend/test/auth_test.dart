import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/api.dart';
import 'package:ludo_club/main.dart';

void main() {
  testWidgets('connection recovery presents retry without requiring login', (
    tester,
  ) async {
    final api = Api();
    await tester.pumpWidget(MaterialApp(home: ConnectionScreen(api: api)));
    expect(find.text('Unable to connect to Ludo Club'), findsOneWidget);
    expect(find.text('Retry connection'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    api.dispose();
  });

  testWidgets('administrator sign-in remains scrollable on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = Api();
    await tester.pumpWidget(MaterialApp(home: AdminLoginScreen(api: api)));
    await tester.ensureVisible(find.text('Sign in'));
    expect(tester.takeException(), isNull);
    api.dispose();
  });
}
