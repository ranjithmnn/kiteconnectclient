import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_snack/expressive_snack.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel hapticChannel = MethodChannel('app.micro_haptics');
  final List<MethodCall> hapticCalls = <MethodCall>[];

  setUp(() {
    hapticCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(hapticChannel, (MethodCall call) async {
          hapticCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(hapticChannel, null);
  });

  testWidgets('applies distinct colors and haptics per ExpressiveSnackType', (
    WidgetTester tester,
  ) async {
    late BuildContext hostContext;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final Set<Color?> backgroundColors = <Color?>{};

    for (final ExpressiveSnackType type in ExpressiveSnackType.values) {
      hapticCalls.clear();

      showExpressiveSnack(
        context: hostContext,
        message: 'Snack ${type.name}',
        type: type,
        icon: Icons.info_outline,
        duration: const Duration(milliseconds: 200),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Snack ${type.name}'), findsOneWidget);
      expect(hapticCalls, isNotEmpty);
      expect(hapticCalls.first.method, 'microTick');

      final Material pillMaterial = tester.widget<Material>(
        find.ancestor(
          of: find.text('Snack ${type.name}'),
          matching: find.byType(Material),
        ).first,
      );
      backgroundColors.add(pillMaterial.color);

      // Let auto-dismiss and overlay removal finish before next variant.
      await tester.pump(const Duration(milliseconds: 700));
    }

    expect(backgroundColors.length, ExpressiveSnackType.values.length);
  });
}
