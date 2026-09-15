import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxvolt_app/src/core/ui/hold_to_stop.dart';

void main() {
  testWidgets('Short touch cancels, full hold opens exactly one confirmation', (tester) async {
    var confirmations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HoldToStop(onConfirm: () => confirmations++)),
      ),
    );
    final target = find.byType(OutlinedButton);
    await tester.tap(target);
    await tester.pump();
    expect(confirmations, 0);
    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2100));
    expect(confirmations, 1);
    await gesture.up();
    await tester.pump();
    expect(confirmations, 1);
  });
}
