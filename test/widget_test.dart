// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:noterat/main.dart';

void main() {
  setUpAll(() {
    // Prevent GoogleFonts from making HTTP requests during tests.
    // Without this, font loading in CI (no network) can silently break
    // widget builds, causing Text widgets to never appear in the tree.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Smoke test - shows configuration page when not configured', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp(isSupabaseConfigured: false));
    // Flush any pending microtasks / font-load callbacks.
    await tester.pump();

    // Verify that the configuration warning page is displayed.
    expect(find.text('Configuration Required'), findsOneWidget);
    expect(find.text('lib/services/supabase_service.dart'), findsOneWidget);
  });
}
