import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e2v_app/src/core/ui/maxvolt_theme.dart';
import 'package:e2v_app/src/features/mobile/presentation/wallet_page.dart';
import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:dio/dio.dart';

class WalletApi extends MobileApi {
  WalletApi() : super('test');
  @override
  Future<Map<String, dynamic>> wallet() async => {
    'balance': 1153.79,
    'app_balance': 33.79,
    'physical_balance': 1120,
    'tags': [],
  };
  @override
  Future<Map<String, dynamic>> walletTransactions() async => {'data': []};
}

class RejectedCheckoutApi extends WalletApi {
  @override
  Future<List<dynamic>> getVehicles() async => [
    {'plate': '5318FPG'},
  ];
  @override
  Future<Map<String, dynamic>> libelulaCheckout(
    double amount, {
    String? razonSocial,
    String? documento,
    String? complemento,
    String? docType,
    String? plate,
  }) async {
    throw DioException(
      requestOptions: RequestOptions(),
      response: Response(
        requestOptions: RequestOptions(),
        statusCode: 422,
        data: {'message': 'Revisa los datos de facturación.'},
      ),
    );
  }
}

void main() {
  testWidgets(
    'Dark wallet input stays readable and 422 preserves wallet route',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: MaxVolt.theme(Brightness.dark),
            home: WalletPage(api: RejectedCheckoutApi()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      final walletScroll = find.byWidgetPredicate((widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down).first;
      await tester.scrollUntilVisible(find.byType(TextField), 200, scrollable: walletScroll);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      final context = tester.element(find.byType(TextField).first);
      final theme = Theme.of(context);
      final background = field.decoration!.fillColor!;
      final foreground = theme.textTheme.bodyLarge!.color!;
      final ratio =
          (foreground.computeLuminance() + .05) /
          (background.computeLuminance() + .05);
      expect(ratio, greaterThan(4.5));
      await tester.scrollUntilVisible(
        find.text('Continuar al pago · QR / tarjeta'),
        150,
        scrollable: walletScroll,
      );
      await tester.tap(find.text('Continuar al pago · QR / tarjeta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUAR A PAGAR'));
      await tester.pumpAndSettle();
      expect(find.text('Revisa los datos de facturación.'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.byType(WalletPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Wallet distinguishes spendable app balance from physical cards',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: MaxVolt.theme(Brightness.light),
            home: WalletPage(api: WalletApi(), displayName: 'Test'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.text('Bs 33.79'), findsOneWidget);
      expect(find.text('Bs 1153.79'), findsNothing);
      expect(find.text('Bs 1120.00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
