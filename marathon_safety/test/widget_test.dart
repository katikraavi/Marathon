import 'package:flutter_test/flutter_test.dart';

import 'package:marathon_safety/main.dart';

void main() {
  testWidgets('Marathon Safety App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MarathonSafetyApp());

    // Verify that the app loads with the expected text.
    expect(find.text('Marathon Safety App - Foundation Ready'), findsOneWidget);
  });
}
