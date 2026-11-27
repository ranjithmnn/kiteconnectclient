import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kiteconnectclient/main.dart';
import 'package:kiteconnectclient/utils/theme/material_themes.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('MyApp applies MaterialThemes light and dark schemes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.colorScheme, MaterialThemes.light.colorScheme);
    expect(
      materialApp.darkTheme?.colorScheme,
      MaterialThemes.dark.colorScheme,
    );
    expect(find.text('Sign in to Kite'), findsOneWidget);
  });
}
