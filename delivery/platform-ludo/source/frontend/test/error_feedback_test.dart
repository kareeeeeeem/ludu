import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/main.dart';

void main() {
  testWidgets('failed actions show a readable error message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => runTask(context, () async {
                        throw Exception('Room unavailable');
                      }),
                  child: const Text('Try'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Try'));
    await tester.pump();
    final message = tester.widget<Text>(find.text('Room unavailable'));
    expect(message.style?.color, isNotNull);
  });
}
