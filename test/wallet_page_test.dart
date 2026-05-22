import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e2v_app/src/features/mobile/presentation/wallet_page.dart';
import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:mockito/mockito.dart';

class MockMobileApi extends Mock implements MobileApi {
  @override
  Future<Map<String, dynamic>> wallet() => Future.value({'balance': 0.0});
  @override
  Future<Map<String, dynamic>> walletTransactions() => Future.value({'data': []});
}

void main() {
  testWidgets('WalletPage builds without crashing', (WidgetTester tester) async {
    final mockApi = MockMobileApi();
    
    await tester.pumpWidget(
      MaterialApp(
        home: WalletPage(api: mockApi, displayName: 'Test User'),
      ),
    );

    expect(find.text('Billetera'), findsOneWidget);
  });
}
