import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e2v_app/src/core/ui/maxvolt_theme.dart';
import 'package:e2v_app/src/features/mobile/presentation/wallet_page.dart';
import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';

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

void main() {
  testWidgets('Wallet distinguishes spendable app balance from physical cards', (tester) async {
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
  });
}
