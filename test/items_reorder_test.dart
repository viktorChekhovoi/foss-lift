import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

/// Reordering a workout's exercises by dragging the grip handle.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late List<ItemDraft> items;
  var changes = 0;

  ItemDraft draft(int id, String name) =>
      ItemDraft(exerciseId: id, name: name, muscle: 'Legs');

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    changes = 0;
    items = [
      draft(1, 'Back Squat'),
      draft(2, 'Leg Press'),
      draft(3, 'Calf Raise'),
    ];
  });
  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark(kDefaultPalette),
            home: Scaffold(
              body: SingleChildScrollView(
                child: WorkoutItemsEditor(
                  items: items,
                  unit: 'kg',
                  routineRest: 90,
                  onChanged: () => changes++,
                ),
              ),
            ),
          ),
        ),
      );

  List<String> names() => items.map((d) => d.name).toList();

  /// The grip on the row at [i], top to bottom.
  Finder grip(int i) => find.byIcon(Icons.drag_indicator).at(i);

  /// Presses a grip and drags it by [dy], which is how a thumb does it. The
  /// grip starts the drag on touch-down — no long press to wait out.
  Future<void> dragBy(WidgetTester tester, int i, double dy) async {
    final drag = await tester.startGesture(tester.getCenter(grip(i)));
    await tester.pump(const Duration(milliseconds: 100));
    // In steps, not one jump: the list re-evaluates where the gap goes as the
    // pointer passes over each row, and a single leap skips that entirely.
    for (var n = 0; n < 8; n++) {
      await drag.moveBy(Offset(0, dy / 8));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await drag.up();
    await tester.pumpAndSettle();
  }

  testWidgets('every row has a grip and no arrows', (tester) async {
    await pump(tester);

    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(3));
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
  });

  testWidgets('dragging a row down moves it past its neighbour',
      (tester) async {
    await pump(tester);
    await dragBy(tester, 0, 80);

    expect(names(), ['Leg Press', 'Back Squat', 'Calf Raise']);
    expect(changes, 1, reason: 'the owner is told the list moved');
  });

  testWidgets('dragging a row up moves it the other way', (tester) async {
    await pump(tester);
    await dragBy(tester, 2, -80);

    expect(names(), ['Back Squat', 'Calf Raise', 'Leg Press']);
  });

  testWidgets('a drag too short to cross a neighbour changes nothing',
      (tester) async {
    await pump(tester);
    await dragBy(tester, 0, 4);

    expect(names(), ['Back Squat', 'Leg Press', 'Calf Raise']);
  });

  testWidgets('tapping a row still opens its settings', (tester) async {
    // The grip takes the drag; the rest of the card keeps the tap.
    await pump(tester);
    await tester.tap(find.text('Leg Press'));
    await tester.pumpAndSettle();

    expect(find.text('TARGET'), findsOneWidget);
  });
}
