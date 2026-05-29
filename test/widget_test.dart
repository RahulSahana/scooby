import 'package:flutter_test/flutter_test.dart';
import 'package:scooby/main.dart';

void main() {
  testWidgets('Navigation smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const Scooby());

    // Verify that we start on the Home Screen.
    expect(find.text('Home Screen'), findsOneWidget);
    expect(find.text('Charge Screen'), findsNothing);

    // Tap the 'Charge' icon and trigger a frame.
    // Use the label to find the navigation item to be more robust.
    await tester.tap(find.text('Charge'));
    await tester.pump();

    // Verify that we are now on the Charge Screen.
    expect(find.text('Home Screen'), findsNothing);
    expect(find.text('Charge Screen'), findsOneWidget);

    // Tap the 'Profile' icon and trigger a frame.
    await tester.tap(find.text('Profile'));
    await tester.pump();

    // Verify that we are now on the Profile Screen.
    expect(find.text('Charge Screen'), findsNothing);
    expect(find.text('Profile Screen'), findsOneWidget);
  });
}
