import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/exercise_progress_screen.dart';
import 'package:foss_lift/theme/app_theme.dart';

/// The progress screen: an empty state before anything is logged, a chart and a
/// live readout once there is history, and a metric toggle that switches the
/// headline. The export uses a platform channel and is not driven here — the
/// CSV it hands over is covered in exercise_stats_test.dart.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int benchId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    benchId = await db.into(db.exercises).insert(
          ExercisesCompanion.insert(name: 'Bench Press'),
        );
  });
  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<void> logSession(
    WidgetTester tester,
    DateTime when,
    List<({double weight, int reps})> sets,
  ) async {
    await tester.runAsync(() async {
      var n = 1;
      await db.saveSession(
        routineId: null,
        workoutId: null,
        name: 'Push',
        startedAt: when,
        endedAt: when.add(const Duration(hours: 1)),
        durationSeconds: 3600,
        totalVolume: 0,
        sets: [
          for (final s in sets)
            SessionSetsCompanion.insert(
              sessionId: 0,
              exerciseId: Value(benchId),
              exerciseName: 'Bench Press',
              setNumber: n++,
              weight: Value(s.weight),
              reps: Value(s.reps),
              done: const Value(true),
            ),
        ],
      );
    });
  }

  Future<void> open(WidgetTester tester) async {
    await tester.runAsync(() async {
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      // Prime the streams so the first frame has data.
      await db.watchExercises().first;
      await db.watchExerciseSetHistory(benchId).first;
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(kDefaultPalette),
        home: ExerciseProgressScreen(exerciseId: benchId),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('empty until something is logged', (tester) async {
    await open(tester);
    expect(find.text('No history yet'), findsOneWidget);
    expect(find.textContaining('the curve starts here'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets); // no chart-specific assert
  });

  testWidgets('draws a chart and a readout once there is history',
      (tester) async {
    await logSession(tester, DateTime(2026, 1, 1), [(weight: 80, reps: 5)]);
    await logSession(tester, DateTime(2026, 1, 8), [(weight: 85, reps: 5)]);
    await open(tester);

    expect(find.text('2 sessions logged'), findsOneWidget);
    // Est 1RM of the last session: 85*(1+5/30) = 99.16 -> "99.2 kg".
    expect(find.text('99.2 kg'), findsOneWidget);
    expect(find.text('LATEST EST. 1RM'), findsOneWidget);
  });

  testWidgets('the metric toggle switches the headline', (tester) async {
    await logSession(tester, DateTime(2026, 1, 1), [(weight: 80, reps: 5)]);
    await logSession(tester, DateTime(2026, 1, 8), [(weight: 85, reps: 5)]);
    await open(tester);

    await tester.tap(find.text('Top set'));
    await tester.pump();

    // Top set of the last session is the bare weight, 85 kg.
    expect(find.text('85 kg'), findsOneWidget);
    expect(find.text('LATEST TOP SET'), findsOneWidget);
  });
}
