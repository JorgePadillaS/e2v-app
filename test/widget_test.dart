import 'package:maxvolt_app/src/core/ui/maxvolt_theme.dart';
import 'package:maxvolt_app/src/features/mobile/presentation/live_charge_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Live charge fits narrow screens and missing SoC in $brightness', (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: MaxVolt.theme(brightness),
          home: Scaffold(
            body: LiveChargeView(
              session: const {
                'id': 1,
                'status': 'Active',
                'currency': 'BOB',
                'total_cost': 14.76,
                'current_metrics': {'power_kw': 72.4, 'energy_kwh': 8.2},
              },
              stale: true,
              onStop: () {},
            ),
          ),
        ),
      );
      expect(find.text('Batería no disponible'), findsOneWidget);
      expect(find.textContaining('Sin actualización'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
