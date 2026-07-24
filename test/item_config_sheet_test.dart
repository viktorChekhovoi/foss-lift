import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/widgets/builder_widgets.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

/// The per-exercise config sheet, which is where every progression setting is
/// actually reachable from. Widget tests fail on a RenderFlex overflow, so this
/// also stands in for eyeballing the sheet on a phone.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late ItemDraft squat;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    squat = ItemDraft(
      exerciseId: 1,
      name: 'Back Squat',
      muscle: 'Legs',
      sets: 4,
      repsMin: 5,
      weightKg: 100,
    );
  });
  tearDown(() {
    container.dispose();
    return db.close();
  });

  /// Pumps the editor over [items] and opens the sheet on the first one.
  Future<void> openSheet(
    WidgetTester tester, {
    List<ItemDraft>? items,
    String unit = 'kg',
  }) async {
    final list = items ?? [squat];
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(kDefaultPalette),
        home: Scaffold(
          body: SingleChildScrollView(
            child: WorkoutItemsEditor(
                items: list, unit: unit, routineRest: 90),
          ),
        ),
      ),
    ));
    await tester.tap(find.text(list.first.name));
    await tester.pumpAndSettle();
  }

  /// The control captioned [label] in the grid.
  Finder underLabel(String label, Finder control) => find.descendant(
        of: find.ancestor(
          of: find.text(label.toUpperCase()),
          matching: find.byType(BuilderField),
        ),
        matching: control,
      );

  group('a counted exercise', () {
    testWidgets('groups its settings into three named cards', (tester) async {
      await openSheet(tester);

      expect(find.text('TARGET'), findsOneWidget);
      expect(find.text('WEIGHT (KG)'), findsOneWidget);
      expect(find.text('PROGRESSION'), findsOneWidget);
      // The four numbers in the progression grid, read back as one rule.
      expect(
        find.textContaining('Add 2.5 kg after 1 clean session'),
        findsOneWidget,
      );
      expect(
          find.textContaining('drop 5 kg after 2 missed ones'), findsOneWidget);
    });

    testWidgets('asks for reps and a range, not a hold', (tester) async {
      await openSheet(tester);

      expect(find.text('SETS'), findsOneWidget);
      expect(find.text('REPS'), findsOneWidget);
      expect(find.text('UP TO'), findsOneWidget);
      expect(find.text('HOLD'), findsNothing);
    });

    testWidgets('offers load and reps as axes, never time', (tester) async {
      await openSheet(tester);

      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Reps'), findsOneWidget);
      expect(find.text('Time'), findsNothing,
          reason: 'you cannot progress a squat by holding it longer');
    });

    testWidgets('switching to the reps axis re-bases the rates',
        (tester) async {
      await openSheet(tester);
      await tester.tap(find.text('Reps'));
      await tester.pumpAndSettle();

      expect(squat.progression, ProgressionMode.reps);
      expect(find.textContaining('Add 1 rep after'), findsOneWidget);
    });
  });

  group('the rep range', () {
    testWidgets('starts empty and says so rather than showing a number',
        (tester) async {
      await openSheet(tester);
      expect(find.text('none'), findsOneWidget);
      expect(squat.repsMax, isNull);
    });

    testWidgets('+ opens it at the lower bound, − closes it again',
        (tester) async {
      await openSheet(tester);
      final upTo = underLabel('Up to', find.byIcon(Icons.add));

      await tester.tap(upTo);
      await tester.pumpAndSettle();
      expect(squat.repsMax, 5);
      expect(find.text('none'), findsNothing);

      // Stepping down past the lower bound drops the bound entirely — there is
      // no separate clear button to knock the row out of alignment.
      await tester.tap(underLabel('Up to', find.byIcon(Icons.remove)));
      await tester.pumpAndSettle();
      expect(squat.repsMax, isNull);
      expect(find.text('none'), findsOneWidget);
    });
  });

  group('to failure', () {
    testWidgets('is a checkbox beside the rep target', (tester) async {
      await openSheet(tester);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('To failure'), findsOneWidget);
    });

    testWidgets('renames the rep target and drops the range', (tester) async {
      await openSheet(tester);
      await tester.tap(find.text('To failure'));
      await tester.pumpAndSettle();

      expect(squat.toFailure, isTrue);
      expect(find.text('REPS TO BEAT'), findsOneWidget);
      expect(find.text('UP TO'), findsNothing,
          reason: 'a range means nothing once the set runs to failure');
    });
  });

  group('a held exercise', () {
    Future<void> openPlank(WidgetTester tester) => openSheet(tester, items: [
          ItemDraft(
            exerciseId: 2,
            name: 'Plank',
            muscle: 'Core',
            measure: ExerciseMeasure.time,
          )
        ]);

    testWidgets('asks for a hold and shows no axis picker', (tester) async {
      await openPlank(tester);

      expect(find.text('HOLD'), findsOneWidget);
      expect(find.text('REPS'), findsNothing);
      expect(find.text('To failure'), findsNothing);
      // One axis is not a choice; the caption says so instead.
      expect(find.text('Weight'), findsNothing);
      expect(find.textContaining('Held for time'), findsOneWidget);
      expect(find.textContaining('Add 5s after 1 clean session'), findsOneWidget);
    });
  });

  group('the rates', () {
    testWidgets('reach the draft when typed', (tester) async {
      await openSheet(tester);

      await tester.enterText(
          underLabel('Step up by', find.byType(TextField)), '1.25');
      await tester.pumpAndSettle();
      expect(squat.increment, 1.25);

      await tester.enterText(
          underLabel('Back off by', find.byType(TextField)), '7.5');
      await tester.pumpAndSettle();
      expect(squat.deload, 7.5);
    });

    testWidgets('are typed in the display unit and stored in kilograms',
        (tester) async {
      await openSheet(tester, unit: 'lb');

      await tester.enterText(
          underLabel('Step up by', find.byType(TextField)), '11');
      await tester.pumpAndSettle();
      expect(squat.increment, closeTo(4.99, 0.01));
    });

    testWidgets('count thresholds, read back in plain English', (tester) async {
      await openSheet(tester);

      final plus = underLabel('Clean sessions', find.byIcon(Icons.add));
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(plus);
        await tester.pumpAndSettle();
        await tester.tap(plus);
        await tester.pumpAndSettle();
      }

      expect(squat.successThreshold, 3);
      expect(find.textContaining('after 3 clean sessions'), findsOneWidget);
    });
  });

  group('getting back out', () {
    testWidgets('the close button in the corner dismisses the sheet',
        (tester) async {
      await openSheet(tester);
      expect(find.text('TARGET'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('TARGET'), findsNothing);
      // And the edits it was opened to make are still there.
      expect(find.text('Back Squat'), findsOneWidget);
    });

    testWidgets('so does Done at the foot of it', (tester) async {
      await openSheet(tester);
      // Which you have to scroll to on a short screen — the reason the close
      // button exists is that this one is not always where you can reach it.
      await tester.ensureVisible(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('TARGET'), findsNothing);
    });

    testWidgets('an edit made in the sheet survives closing it',
        (tester) async {
      await openSheet(tester);
      await tester.tap(underLabel('Sets', find.byIcon(Icons.add)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(squat.sets, 5);
      expect(find.textContaining('5 × 5'), findsOneWidget,
          reason: 'the card behind it caught up');
    });
  });

  testWidgets('rest says whether it is the routine default or an override',
      (tester) async {
    await openSheet(tester);
    expect(find.text('REST · DEFAULT'), findsOneWidget);

    await tester.tap(underLabel('Rest · default', find.byIcon(Icons.add)));
    await tester.pumpAndSettle();

    expect(squat.restSeconds, 105);
    expect(find.text('REST · CUSTOM'), findsOneWidget);
  });
}
