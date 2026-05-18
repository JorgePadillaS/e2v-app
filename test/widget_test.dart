import 'package:e2v_app/src/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app renders', (tester) async {
    await tester.pumpWidget(const E2VApp());
    expect(find.textContaining('E2V App'), findsOneWidget);
  });
}
