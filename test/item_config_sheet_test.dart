import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

/// The per-exercise config sheet, which is where every progression setting is
/// actually reachable from. Widget tests fail on a RenderFlex overflow, so this
/// also stands in for eyeballing the sheet on a phone.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late ItemDraft draft;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    draft = ItemDraft(
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

  /// Pumps the editor and opens the sheet on its single item.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: WorkoutItemsEditor(
              items: [draft],
              unit: 'kg',
              routineRest: 90,
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Back Squat'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the weight axis with its rates', (tester) async {
    await openSheet(tester);

    expect(find.text('PROGRESS BY'), findsOneWidget);
    expect(find.text('Step up by'), findsOneWidget);
    expect(find.text('Back off by'), findsOneWidget);
    // The plain-English restatement of whatever the controls currently say.
    expect(
      find.textContaining('Add 2.5 kg after 1 clean session'),
      findsOneWidget,
    );
    expect(find.textContaining('drop 5 kg after 2 missed ones'), findsOneWidget);
  });

  testWidgets('the weight axis asks for reps, not a hold', (tester) async {
    await openSheet(tester);

    expect(find.text('Min reps'), findsOneWidget);
    expect(find.text('To failure'), findsOneWidget);
    expect(find.text('Hold'), findsNothing);
  });

  testWidgets('choosing Time swaps reps for a hold and re-bases the rates',
      (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();

    expect(find.text('Hold'), findsOneWidget);
    expect(find.text('Min reps'), findsNothing);
    expect(find.text('To failure'), findsNothing,
        reason: 'a hold cannot be taken to failure in reps');

    expect(draft.progression, ProgressionMode.time);
    expect([draft.increment, draft.deload], [5, 10]);
    expect(find.textContaining('Add 5s after 1 clean session'), findsOneWidget);
  });

  testWidgets('choosing Reps keeps the rep controls but changes the unit',
      (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Reps'));
    await tester.pumpAndSettle();

    expect(find.text('Min reps'), findsOneWidget);
    expect(draft.progression, ProgressionMode.reps);
    expect(find.textContaining('Add 1 rep after'), findsOneWidget);
  });

  /// The control sitting opposite [label] on its row.
  Finder besideLabel(String label, Finder control) => find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(Row)),
        matching: control,
      );

  testWidgets('a typed rate reaches the draft', (tester) async {
    await openSheet(tester);

    await tester.enterText(
        besideLabel('Step up by', find.byType(TextField)), '1.25');
    await tester.pumpAndSettle();
    expect(draft.increment, 1.25);

    await tester.enterText(
        besideLabel('Back off by', find.byType(TextField)), '7.5');
    await tester.pumpAndSettle();
    expect(draft.deload, 7.5);
  });

  testWidgets('a typed weight rate is stored in kilograms', (tester) async {
    // The field speaks the display unit like every other weight in the app.
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: WorkoutItemsEditor(
                items: [draft], unit: 'lb', routineRest: 90),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Back Squat'));
    await tester.pumpAndSettle();

    await tester.enterText(
        besideLabel('Step up by', find.byType(TextField)), '11');
    await tester.pumpAndSettle();
    expect(draft.increment, closeTo(4.99, 0.01));
  });

  testWidgets('thresholds are configurable and read back in plain English',
      (tester) async {
    await openSheet(tester);

    // The rates live at the foot of a sheet taller than the test surface.
    final plus =
        besideLabel('Clean sessions to step up', find.byIcon(Icons.add));
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(plus);
      await tester.pumpAndSettle();
      await tester.tap(plus);
      await tester.pumpAndSettle();
    }

    expect(draft.successThreshold, 3);
    expect(find.textContaining('after 3 clean sessions'), findsOneWidget);
  });
}
