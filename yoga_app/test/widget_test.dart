import 'package:flutter_test/flutter_test.dart';

import 'package:yoga_app/main.dart';

void main() {
  testWidgets('Yoga Video App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const YogaVideoApp());

    // Verify app title or initial state
    expect(find.text('Yoga Video Manager'), findsOneWidget);
  });
}
