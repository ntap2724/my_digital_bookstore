// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Reset in-memory SharedPreferences for tests
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Splash navigates to Login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Splash should appear first
    expect(find.text('Chào mừng!'), findsOneWidget);

    // Wait for splash delay (~1200ms) and navigation
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    // Login screen should be visible
    expect(find.text('Đăng nhập'), findsWidgets);
  });
}
