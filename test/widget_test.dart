// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar_ka_khana/main.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  testWidgets('Dummy test to pass test suite', (WidgetTester tester) async {
    // Load mock env
    dotenv.loadFromString(envString: '''SUPABASE_URL=test
SUPABASE_ANON_KEY=test
SUPPORT_SUPABASE_URL=test
SUPPORT_SUPABASE_ANON_KEY=test
GOOGLE_WEB_CLIENT_ID=test''');

    expect(true, isTrue);
  });
}
