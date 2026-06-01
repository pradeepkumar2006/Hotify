import 'package:flutter_test/flutter_test.dart';
import 'package:hotify/main.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_core/firebase_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('Hotify basic boot test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HotifyApp());

    // Verify that our base app text exists.
    expect(find.textContaining('HOTIFY'), findsWidgets);

    // Let the timer fire by advancing the clock
    await tester.pump(const Duration(seconds: 4));
    // Let the navigation transition settle
    await tester.pumpAndSettle();
  });
}
