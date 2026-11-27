import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kiteconnectclient/utils/theme/material_themes.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_dialog/expressive_dialog.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_shapes/expressive_shapes.dart';
import 'package:material_ui/material_ui.dart'
    hide MaterialShapes, MaterialShapeBorder, RoundedPolygon, CornerRounding;

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildHost({
    required ThemeData theme,
    required void Function(BuildContext context) onOpen,
  }) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => FilledButton(
              onPressed: () => onOpen(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('lays out 2 buttons horizontally and animates popup and removal',
      (WidgetTester tester) async {
    ExpressiveDialogButton? result;
    bool destructiveClicked = false;

    await tester.pumpWidget(
      buildHost(
        theme: MaterialThemes.light,
        onOpen: (context) async {
          result = await showExpressiveDialog(
            context: context,
            title: 'Log out',
            message: 'You will need to sign in again.',
            icon: Icons.logout_rounded,
            buttons: [
              const ExpressiveDialogButton(
                label: 'Cancel',
                role: ExpressiveDialogButtonRole.secondary,
              ),
              ExpressiveDialogButton(
                label: 'Log out',
                role: ExpressiveDialogButtonRole.destructive,
                onPressed: () => destructiveClicked = true,
              ),
            ],
          );
        },
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Log out'), findsNWidgets(2));
    expect(find.text('You will need to sign in again.'), findsOneWidget);

    final cancelRect = tester.getRect(find.text('Cancel'));
    final logoutButtonFinder = find.descendant(
      of: find.byType(Row),
      matching: find.text('Log out'),
    );
    final logoutRect = tester.getRect(logoutButtonFinder);

    // 2 buttons must sit side by side on the same horizontal axis.
    expect(cancelRect.center.dy, closeTo(logoutRect.center.dy, 1.0));
    expect(logoutRect.left, greaterThan(cancelRect.right));

    // Verify main icon badge uses cookie9Sided + loader colors
    // (primaryContainer / onPrimaryContainer).
    final iconFinder = find.byIcon(Icons.logout_rounded);
    final iconWidget = tester.widget<Icon>(iconFinder);
    expect(iconWidget.color, MaterialThemes.light.colorScheme.onPrimaryContainer);
    final badgeContainer = tester.widget<Container>(
      find.ancestor(of: iconFinder, matching: find.byType(Container)).first,
    );
    final badgeDecoration = badgeContainer.decoration! as ShapeDecoration;
    expect(badgeDecoration.color, MaterialThemes.light.colorScheme.primaryContainer);
    expect(
      (badgeDecoration.shape as MaterialShapeBorder).shape,
      MaterialShapes.cookie9Sided,
    );

    // Verify destructive pill uses theme error color.
    final destructiveMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: logoutButtonFinder,
            matching: find.byType(Material),
          )
          .first,
    );
    expect(destructiveMaterial.color, MaterialThemes.light.colorScheme.error);

    // Tap destructive button and verify removal animation completes cleanly.
    await tester.tap(logoutButtonFinder);
    await tester.pumpAndSettle();

    expect(destructiveClicked, isTrue);
    expect(result?.label, 'Log out');
    expect(result?.role, ExpressiveDialogButtonRole.destructive);
    expect(find.byType(ExpressiveDialog), findsNothing);
  });

  testWidgets('stacks more than 2 buttons vertically and honors dark theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildHost(
        theme: MaterialThemes.dark,
        onOpen: (context) {
          showExpressiveDialog(
            context: context,
            title: 'Discard changes?',
            message: 'Choose how to proceed with your draft order.',
            buttons: const [
              ExpressiveDialogButton(
                label: 'Save draft',
                role: ExpressiveDialogButtonRole.primary,
              ),
              ExpressiveDialogButton(
                label: 'Discard',
                role: ExpressiveDialogButtonRole.destructiveTonal,
              ),
              ExpressiveDialogButton(
                label: 'Keep editing',
                role: ExpressiveDialogButtonRole.text,
              ),
            ],
          );
        },
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final saveRect = tester.getRect(find.text('Save draft'));
    final discardRect = tester.getRect(find.text('Discard'));
    final keepRect = tester.getRect(find.text('Keep editing'));

    // 3 buttons must stack vertically top-to-bottom.
    expect(discardRect.top, greaterThan(saveRect.bottom));
    expect(keepRect.top, greaterThan(discardRect.bottom));

    // Verify destructiveTonal pill uses dark theme errorContainer.
    final discardMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.text('Discard'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(
      discardMaterial.color,
      MaterialThemes.dark.colorScheme.errorContainer,
    );

    // Dialog container uses dark surfaceContainerHigh.
    final dialogMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(ExpressiveDialog),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(
      dialogMaterial.color,
      MaterialThemes.dark.colorScheme.surfaceContainerHigh,
    );
  });

  testWidgets('supports dismissOnPressed: false and barrierDismissible', (
    WidgetTester tester,
  ) async {
    int count = 0;
    ExpressiveDialogButton? result = const ExpressiveDialogButton(label: 'init');

    await tester.pumpWidget(
      buildHost(
        theme: MaterialThemes.light,
        onOpen: (context) async {
          result = await showExpressiveDialog(
            context: context,
            title: 'Confirm',
            message: 'Tap stay to keep open.',
            buttons: [
              ExpressiveDialogButton(
                label: 'Stay',
                dismissOnPressed: false,
                onPressed: () => count++,
              ),
            ],
          );
        },
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(count, 1);
    expect(find.byType(ExpressiveDialog), findsOneWidget);

    // Tap top-left corner barrier to dismiss.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(ExpressiveDialog), findsNothing);
    expect(result, isNull);
  });
}

