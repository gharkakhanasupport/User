import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_sms_gateway/main.dart';

void main() {
  testWidgets('Gateway app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GKKGatewayApp());
    expect(find.text('GKK SMS Gateway'), findsOneWidget);
  });
}
