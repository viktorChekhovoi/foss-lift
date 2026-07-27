// Integration tests for features/14-routine-sharing.md — sharing a routine.
//
// The behaviour under test, straight from the spec:
//   * a routine encodes to one versioned, compressed line (`FLR1.…`) carrying
//     the whole programme — days, slots, rep schemes, progression rates;
//   * the exercises it references travel with it, custom ones in full;
//   * defaults are not transmitted, so an ordinary routine fits in a QR;
//   * an import is previewed and accepted, never applied on arrival, and always
//     lands as a new routine without taking over Today;
//   * an incoming exercise whose name already exists is the user's call —
//     keep mine (the default) or replace, editing in place so history survives;
//   * the three ways a code can fail each say what to do and offer no partial
//     import.
//
// Exercised through the real public surface: the codec, the arrival plan, the
// database methods, the link mapping and the two screens.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/routine_code.dart';
import 'package:foss_lift/data/routine_import.dart';
import 'package:foss_lift/data/share_code.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/routine_import_screen.dart';
import 'package:foss_lift/screens/routine_share_screen.dart';
import 'package:foss_lift/services/deep_links.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/theme/theme_code.dart';
import 'package:foss_lift/util/qr_capacity.dart';
import 'package:foss_lift/util/video_links.dart';

import 'support/harness.dart';
import 'support/settle.dart';

/// A run of [length] characters that will not compress, seeded by [seed].
///
/// Deflate is good enough at ordinary English that a routine of realistically
/// named exercises fits in a QR code however many of them there are — which is
/// the format working, not a test fixture working. Only genuinely
/// incompressible text gets a routine past the largest symbol, so that is what
/// this makes.
String _noise(int seed, int length) {
  const alphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  var state = seed * 2654435761 + 12345;
  return String.fromCharCodes([
    for (var i = 0; i < length; i++)
      () {
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
        return alphabet.codeUnitAt((state >> 16) % alphabet.length);
      }(),
  ]);
}

/// The seeded demo routine, looked up by name — ids are an implementation
/// detail of the seed order.
Future<Routine> _routineNamed(AppDatabase db, String name) async {
  final all = await db.watchRoutines().first;
  return all.map((r) => r.routine).firstWhere((r) => r.name == name);
}

Future<Exercise?> _exerciseNamed(AppDatabase db, String name) async {
  final all = await db.watchExercises().first;
  for (final e in all) {
    if (e.name == name) return e;
  }
  return null;
}

/// A routine built around one custom exercise, with a slot that is deliberately
/// default in nothing: every field the wire format can carry is set to
/// something other than the app's default, so a round trip has something to
/// lose.
Future<int> _seedCustomRoutine(AppDatabase db) async {
  final exerciseId = await db.createExercise(
    name: 'Zercher Squat',
    muscle: 'Legs',
    equipment: 'Barbell',
    videoUrl: 'https://www.youtube.com/watch?v=aBcD1234_-x&t=90s',
    measure: ExerciseMeasure.reps,
    weightType: WeightType.bar,
  );
  await db.setExerciseBarWeight(exerciseId, 15);

  final routineId = await db.createRoutine(
    name: 'Elbow Day',
    color: '3ED598',
    restSeconds: 210,
    scheduleDays: 1 << 1 | 1 << 3,
    reminderMinutes: 18 * 60,
  );
  await db.replaceRoutineWorkouts(routineId, [
    (
      id: null,
      name: 'Zerchers',
      items: [
        WorkoutItemsCompanion.insert(
          workoutId: 0,
          exerciseId: exerciseId,
          position: const Value(0),
          targetSets: const Value(6),
          repsMin: const Value(3),
          repsMax: const Value(5),
          restSeconds: const Value(240),
          suggestedWeight: const Value(102.5),
          progression: const Value(ProgressionMode.weight),
          increment: const Value(5),
          deload: const Value(12.5),
          successThreshold: const Value(3),
          failureThreshold: const Value(4),
          // Streaks the sender has built up. These must not travel.
          successStreak: const Value(2),
          failStreak: const Value(1),
        ),
      ],
    ),
  ]);
  return routineId;
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  group('the wire format', () {
    test('a seeded routine round-trips whole', () async {
      final ppl = await _routineNamed(db, 'Push / Pull / Legs');
      final shared = await db.sharedRoutine(ppl.id);

      final result = RoutineCode.decode(RoutineCode.encode(shared));
      expect(result, isA<RoutineCodeOk>());
      final back = (result as RoutineCodeOk).routine;

      expect(back.name, 'Push / Pull / Legs');
      expect(back.colorHex, 'FF6A3D');
      expect(back.restSeconds, 120);
      expect(back.scheduleDays, ppl.scheduleDays,
          reason: 'the training days are part of the programme');
      expect(back.workouts.map((w) => w.name), ['Push', 'Pull', 'Legs']);
      expect(back.workouts.map((w) => w.items.length), [5, 5, 5]);

      final bench = back.workouts.first.items.first;
      expect(back.exercises[bench.exercise].name, 'Bench Press');
      expect(bench.targetSets, 4);
      expect(bench.repsMin, 6);
      expect(bench.repsMax, 8);
      expect(bench.suggestedWeight, 80);
      expect(bench.progression, ProgressionMode.weight);

      // A pull-up: no load, so the seed puts it on the reps axis with that
      // mode's own increment rather than the weight-mode default.
      final pullUp = back.workouts[1].items[1];
      expect(back.exercises[pullUp.exercise].name, 'Pull-Up');
      expect(pullUp.progression, ProgressionMode.reps);
      expect(pullUp.suggestedWeight, isNull);
      expect(pullUp.increment, ProgressionMode.reps.defaultIncrement);
    });

    test('every configurable field on a slot survives the trip', () async {
      final routineId = await _seedCustomRoutine(db);
      final shared = await db.sharedRoutine(routineId);

      final back =
          (RoutineCode.decode(RoutineCode.encode(shared)) as RoutineCodeOk)
              .routine;

      expect(back.name, 'Elbow Day');
      expect(back.colorHex, '3ED598');
      expect(back.restSeconds, 210);
      expect(back.scheduleDays, 1 << 1 | 1 << 3);

      final slot = back.workouts.single.items.single;
      expect(slot.targetSets, 6);
      expect(slot.repsMin, 3);
      expect(slot.repsMax, 5);
      expect(slot.restSeconds, 240);
      expect(slot.suggestedWeight, 102.5);
      expect(slot.increment, 5);
      expect(slot.deload, 12.5);
      expect(slot.successThreshold, 3);
      expect(slot.failureThreshold, 4);
    });

    test('a held movement carries its hold, not a rep count', () async {
      final plank = await _exerciseNamed(db, 'Plank');
      final routineId = await db.createRoutine(
        name: 'Core',
        color: 'FF6A3D',
        restSeconds: 60,
      );
      await db.replaceRoutineWorkouts(routineId, [
        (
          id: null,
          name: 'Holds',
          items: [
            WorkoutItemsCompanion.insert(
              workoutId: 0,
              exerciseId: plank!.id,
              progression: const Value(ProgressionMode.time),
              holdSeconds: const Value(75),
              increment: const Value(10),
            ),
          ],
        ),
      ]);

      final shared = await db.sharedRoutine(routineId);
      final back =
          (RoutineCode.decode(RoutineCode.encode(shared)) as RoutineCodeOk)
              .routine;

      final slot = back.workouts.single.items.single;
      expect(slot.progression, ProgressionMode.time);
      expect(slot.holdSeconds, 75);
      expect(slot.increment, 10);
      expect(back.exercises[slot.exercise].measure, ExerciseMeasure.time);
    });

    test('a custom exercise travels in full; a built-in travels by name',
        () async {
      final custom = await db.sharedRoutine(await _seedCustomRoutine(db));
      final theirs =
          (RoutineCode.decode(RoutineCode.encode(custom)) as RoutineCodeOk)
              .routine
              .exercises
              .single;

      expect(theirs.name, 'Zercher Squat');
      expect(theirs.isCustom, isTrue);
      expect(theirs.muscleGroup, 'Legs');
      expect(theirs.equipment, 'Barbell');
      expect(theirs.weightType, WeightType.bar);
      expect(theirs.barWeight, 15,
          reason: "the sender's bar for this movement is part of the exercise");
      // The link travels as its video id and comes back canonical: the
      // timestamp, the tracking parameters and the www. are all noise.
      expect(theirs.videoUrl, 'https://youtu.be/aBcD1234_-x');

      // A starter-library movement is on both phones already: spending 120
      // characters on its coaching cue would be paying for a copy of something
      // the recipient has.
      final ppl = await db.sharedRoutine((await _routineNamed(db, 'Push / Pull / Legs')).id);
      final builtIn =
          (RoutineCode.decode(RoutineCode.encode(ppl)) as RoutineCodeOk)
              .routine
              .exercises
              .firstWhere((e) => e.name == 'Bench Press');
      expect(builtIn.isCustom, isFalse);
      // The starter library's demo links are YouTube *searches* — there is no
      // video behind them to name, so nothing travels.
      expect(builtIn.videoUrl, isNull);
    });

    test('the sender\'s streaks and reminder stay behind', () async {
      final shared = await db.sharedRoutine(await _seedCustomRoutine(db));
      final code = RoutineCode.encode(shared);

      final fresh = memoryDb();
      addTearDown(fresh.close);
      final newId = await fresh
          .importSharedRoutine((RoutineCode.decode(code) as RoutineCodeOk).routine);
      final routine = await fresh.routineById(newId);
      expect(routine.reminderMinutes, isNull,
          reason: 'a notification is asked for, never inherited');
      expect(routine.scheduleDays, 1 << 1 | 1 << 3);

      final workout = (await fresh.workoutsForRoutine(newId)).single;
      final item = (await fresh.itemsForWorkout(workout.id)).single.item;
      expect(item.successStreak, 0);
      expect(item.failStreak, 0);
      expect(item.suggestedWeight, 102.5);
    });

    test('an ordinary routine is small enough for a QR code', () async {
      final ppl = await db.sharedRoutine((await _routineNamed(db, 'Push / Pull / Legs')).id);
      final link = RoutineCode.link(ppl);

      expect(RoutineCode.fitsQr(link), isTrue,
          reason: 'the demo routine must be shareable as a QR');
      expect(link.length, lessThan(RoutineCode.qrLinkLimit));
      expect(qrEccFor(link.length), QrEcc.medium,
          reason: 'and with room to spare for error correction');
    });

    test('a routine too big for any QR says so rather than painting one',
        () async {
      // With cues gone, names are the only field a person can make long enough
      // to run a routine past a version-40 symbol — and it takes sixty of them
      // at the full length, in text that will not compress.
      final routineId = await db.createRoutine(
          name: 'Everything', color: 'FF6A3D', restSeconds: 90);
      final items = <WorkoutItemsCompanion>[];
      for (var i = 0; i < 60; i++) {
        final id = await db.createExercise(
          name: _noise(i, 80),
          muscle: 'Other',
          equipment: 'Machine',
        );
        items.add(WorkoutItemsCompanion.insert(
            workoutId: 0, exerciseId: id, position: Value(i)));
      }
      await db.replaceRoutineWorkouts(
          routineId, [(id: null, name: 'All of it', items: items)]);

      final link = RoutineCode.link(await db.sharedRoutine(routineId));
      expect(link.length, greaterThan(RoutineCode.qrLinkLimit),
          reason: 'this is the case the QR limit exists for');
      expect(RoutineCode.fitsQr(link), isFalse);
      expect(qrEccFor(link.length), isNull);

      // Still perfectly shareable every other way — the code itself is fine.
      expect((RoutineCode.decode(link) as RoutineCodeOk).routine.exercises,
          hasLength(60));
    });

    test('a big routine spends its error correction to stay scannable', () {
      // Between the two capacities a symbol is still worth painting, just with
      // less redundancy — a worse QR beats no QR when the fallback is a link.
      expect(qrEccFor(kQrBytesMediumEcc), QrEcc.medium);
      expect(qrEccFor(kQrBytesMediumEcc + 1), QrEcc.low);
      expect(qrEccFor(kQrBytesLowEcc), QrEcc.low);
      expect(qrEccFor(kQrBytesLowEcc + 1), isNull);
    });

    test('defaults cost nothing to send', () async {
      final plain = await db.createRoutine(
        name: 'Plain',
        color: 'FF6A3D',
        restSeconds: 90,
      );
      final loud = await db.createRoutine(
        name: 'Loud!',
        color: 'FF6A3D',
        restSeconds: 90,
      );
      final bench = (await _exerciseNamed(db, 'Bench Press'))!;
      await db.replaceRoutineWorkouts(plain, [
        (
          id: null,
          name: 'A',
          items: [
            for (var i = 0; i < 5; i++)
              WorkoutItemsCompanion.insert(
                workoutId: 0,
                exerciseId: bench.id,
                position: Value(i),
              ),
          ],
        ),
      ]);
      await db.replaceRoutineWorkouts(loud, [
        (
          id: null,
          name: 'A',
          items: [
            for (var i = 0; i < 5; i++)
              WorkoutItemsCompanion.insert(
                workoutId: 0,
                exerciseId: bench.id,
                position: Value(i),
                targetSets: const Value(7),
                repsMin: const Value(11),
                repsMax: const Value(13),
                restSeconds: const Value(255),
                suggestedWeight: const Value(97.5),
                increment: const Value(7.5),
                deload: const Value(17.5),
                successThreshold: const Value(4),
                failureThreshold: const Value(5),
              ),
          ],
        ),
      ]);

      final plainCode = RoutineCode.encode(await db.sharedRoutine(plain));
      final loudCode = RoutineCode.encode(await db.sharedRoutine(loud));
      expect(plainCode.length, lessThan(loudCode.length),
          reason: 'a slot left at its defaults must not be spelled out');
    });
  });

  group('what a code refuses to carry', () {
    test('a video link travels as its id, whatever form it arrived in', () {
      // Every shape a person might paste, and the one canonical form back.
      const id = 'aBcD1234_-x';
      for (final url in [
        'https://www.youtube.com/watch?v=$id',
        'https://www.youtube.com/watch?v=$id&list=PLxyz&index=2',
        'https://youtu.be/$id',
        'https://youtu.be/$id?t=42',
        'https://m.youtube.com/watch?v=$id',
        'https://www.youtube.com/shorts/$id',
        'https://www.youtube.com/embed/$id',
        'youtube.com/watch?v=$id',
      ]) {
        expect(youTubeVideoId(url), id, reason: url);
      }
    });

    test('a link with no video behind it does not travel', () {
      for (final url in [
        // What the starter library generates: a search, not a video.
        'https://www.youtube.com/results?search_query=bench+press+proper+form',
        'https://example.com/my-technique',
        'https://youtu.be/tooshort',
        'not a url at all',
        '',
      ]) {
        expect(youTubeVideoId(url), isNull, reason: url);
      }
    });

    test('a name longer than the format carries is cut, not refused', () async {
      final long = 'Z' * (RoutineCode.maxNameBytes + 200);
      final routineId = await db.createRoutine(
          name: 'Fine', color: 'FF6A3D', restSeconds: 90);
      await db.replaceRoutineWorkouts(routineId, [
        (
          id: null,
          name: long.substring(0, 80),
          items: [
            WorkoutItemsCompanion.insert(
                workoutId: 0,
                exerciseId: (await _exerciseNamed(db, 'Plank'))!.id),
          ],
        ),
      ]);

      // The database caps names at 80, so the only way to get an over-long one
      // onto the wire is to build the shared routine by hand — which is exactly
      // what a hostile or buggy sender would do.
      final shared = await db.sharedRoutine(routineId);
      final oversized = SharedRoutine(
        name: long,
        colorHex: shared.colorHex,
        restSeconds: shared.restSeconds,
        scheduleDays: shared.scheduleDays,
        exercises: shared.exercises,
        workouts: shared.workouts,
      );

      final back = (RoutineCode.decode(RoutineCode.encode(oversized))
              as RoutineCodeOk)
          .routine;
      expect(back.name.length, RoutineCode.maxNameBytes,
          reason: 'cut to the limit rather than failing the whole export');
      expect(back.name, long.substring(0, RoutineCode.maxNameBytes));
    });

    test('a name limit generous enough that nobody meets it', () {
      // The database stops at 80; the wire format leaves room above that so a
      // future longer name never silently loses characters here first.
      expect(RoutineCode.maxNameBytes, greaterThan(80));
    });
  });

  group('a code that will not read', () {
    Future<String> aCode() async =>
        RoutineCode.encode(await db.sharedRoutine(await _seedCustomRoutine(db)));

    test('is version-tagged so a later format can be told apart', () async {
      expect(await aCode(), startsWith('FLR1.'));
    });

    test('a code tagged with another format version is simply not a code',
        () async {
      final other = (await aCode()).replaceFirst('FLR1', 'FLR9');
      final result = RoutineCode.decode(other);
      expect(result, isA<RoutineCodeFailure>());
      expect(
          (result as RoutineCodeFailure).problem, ShareCodeProblem.notACode);
    });

    test('text that is not a routine code at all is rejected as such',
        () async {
      final junk = [
        '',
        'hello',
        'https://example.com',
        '{"routine":{}}',
        // A theme code is a real Foss Lift code, and still not a routine.
        ThemeCode.encode(kDefaultPalette),
      ];
      for (final text in junk) {
        final result = RoutineCode.decode(text);
        expect(result, isA<RoutineCodeFailure>(), reason: 'decoding "$text"');
        expect((result as RoutineCodeFailure).problem,
            ShareCodeProblem.notACode,
            reason: 'decoding "$text"');
      }
    });

    test('a truncated code is caught rather than importing half a routine',
        () async {
      final code = await aCode();
      for (var cut = 1; cut < 12; cut++) {
        final result = RoutineCode.decode(code.substring(0, code.length - cut));
        expect(result, isA<RoutineCodeFailure>(),
            reason: 'a code missing $cut characters must not decode');
        expect((result as RoutineCodeFailure).problem, ShareCodeProblem.damaged,
            reason: 'a code missing $cut characters is damaged, not foreign');
      }
    });

    test('a flipped character never decodes to a different routine', () async {
      final code = await aCode();
      for (var i = 'FLR1.'.length; i < code.length; i++) {
        final ch = code[i] == 'A' ? 'B' : 'A';
        final result = RoutineCode.decode(code.replaceRange(i, i + 1, ch));
        if (result is! RoutineCodeFailure) {
          fail('a one-character corruption at $i decoded silently');
        }
      }
    });

    test('a link, or a code with whitespace through it, still reads', () async {
      final shared = await db.sharedRoutine(await _seedCustomRoutine(db));
      final code = RoutineCode.encode(shared);

      for (final source in [
        RoutineCode.link(shared),
        '  $code\n',
        code.replaceRange(20, 20, '\n  '),
      ]) {
        final result = RoutineCode.decode(source);
        expect(result, isA<RoutineCodeOk>(), reason: 'decoding "$source"');
        expect((result as RoutineCodeOk).routine.name, 'Elbow Day');
      }
    });
  });

  group('landing an import', () {
    /// A code made on "their" phone, against a database this test can also
    /// inspect — sharing is between two installs, so the tests need both.
    Future<SharedRoutine> theirs(Future<int> Function(AppDatabase) build) async {
      final sender = memoryDb();
      addTearDown(sender.close);
      return sender.sharedRoutine(await build(sender));
    }

    test('re-creates the routine faithfully, workouts and rep schemes and all',
        () async {
      final shared = await theirs((s) async => (await _routineNamed(s, 'Push / Pull / Legs')).id);

      final id = await db.importSharedRoutine(shared);
      final routine = await db.routineById(id);
      expect(routine.name, 'Push / Pull / Legs');
      expect(routine.colorHex, 'FF6A3D');
      expect(routine.restSeconds, 120);

      final days = await db.workoutsForRoutine(id);
      expect(days.map((w) => w.name), ['Push', 'Pull', 'Legs']);

      final push = await db.itemsForWorkout(days.first.id);
      expect(push.map((v) => v.exercise.name),
          ['Bench Press', 'Overhead Press', 'Incline DB Press', 'Lateral Raise', 'Triceps Pushdown']);
      expect(push.first.item.targetSets, 4);
      expect(push.first.item.repsMin, 6);
      expect(push.first.item.repsMax, 8);
      expect(push.first.item.suggestedWeight, 80);
    });

    test('reuses the library rather than duplicating it', () async {
      final shared = await theirs((s) async => (await _routineNamed(s, 'Push / Pull / Legs')).id);
      final before = (await db.watchExercises().first).length;

      await db.importSharedRoutine(shared);
      await db.importSharedRoutine(shared);

      expect((await db.watchExercises().first).length, before,
          reason: 'the starter library is on both phones already');
      final routines = await db.watchRoutines().first;
      expect(routines.where((r) => r.routine.name == 'Push / Pull / Legs'),
          hasLength(3),
          reason: 'two imports plus the one that was already here');
    });

    test('brings a custom exercise the recipient has never seen', () async {
      final shared = await theirs(_seedCustomRoutine);
      expect(await _exerciseNamed(db, 'Zercher Squat'), isNull);

      final arrivals = planExerciseArrivals(
          shared.exercises, await db.watchExercises().first);
      expect(arrivals.single.isNew, isTrue);
      expect(arrivals.single.clashes, isFalse);

      final id = await db.importSharedRoutine(shared);
      final landed = await _exerciseNamed(db, 'Zercher Squat');
      expect(landed, isNotNull);
      expect(landed!.isCustom, isTrue);
      expect(landed.weightType, WeightType.bar);
      expect(landed.barWeight, 15);
      expect(landed.videoUrl, 'https://youtu.be/aBcD1234_-x');

      final day = (await db.workoutsForRoutine(id)).single;
      expect((await db.itemsForWorkout(day.id)).single.exercise.id, landed.id);
    });

    test('does not take over Today', () async {
      final shared = await theirs(_seedCustomRoutine);
      final before = await db.watchActiveRoutineId().first;

      await db.importSharedRoutine(shared);

      expect(await db.watchActiveRoutineId().first, before,
          reason: 'importing a routine is not choosing it');
    });
  });

  group('an exercise whose name is already taken', () {
    /// Their "Zercher Squat" against mine, which differs — the case that has to
    /// ask rather than guess.
    Future<SharedRoutine> theirZercher() async {
      final sender = memoryDb();
      addTearDown(sender.close);
      return sender.sharedRoutine(await _seedCustomRoutine(sender));
    }

    Future<Exercise> myZercher() async {
      final id = await db.createExercise(
        name: 'Zercher Squat',
        muscle: 'Other',
        equipment: 'Machine',
        weightType: WeightType.machine,
      );
      return db.exerciseById(id);
    }

    test('is a clash the user is asked about, not a silent overwrite',
        () async {
      final mine = await myZercher();
      final shared = await theirZercher();

      final arrivals = planExerciseArrivals(
          shared.exercises, await db.watchExercises().first);
      expect(arrivals.single.isNew, isFalse);
      expect(arrivals.single.clashes, isTrue);
      expect(arrivals.single.existing!.id, mine.id);

      // Default: keep mine.
      final id = await db.importSharedRoutine(shared);
      final kept = await db.exerciseById(mine.id);
      expect(kept.equipment, 'Machine');
      expect(kept.barWeight, isNull);

      final day = (await db.workoutsForRoutine(id)).single;
      expect((await db.itemsForWorkout(day.id)).single.exercise.id, mine.id,
          reason: 'the routine points at the exercise I kept');
      expect((await db.watchExercises().first).where((e) => e.name == 'Zercher Squat'),
          hasLength(1), reason: 'never a second copy under the same name');
    });

    test('replacing edits in place, so history and other routines survive',
        () async {
      final mine = await myZercher();
      final shared = await theirZercher();

      final id = await db.importSharedRoutine(shared, replace: {0});

      final now = await db.exerciseById(mine.id);
      expect(now.id, mine.id, reason: 'the same row, rewritten');
      expect(now.equipment, 'Barbell');
      expect(now.muscleGroup, 'Legs');
      expect(now.weightType, WeightType.bar);
      expect(now.barWeight, 15);

      final day = (await db.workoutsForRoutine(id)).single;
      expect((await db.itemsForWorkout(day.id)).single.exercise.id, mine.id);
    });

    test('a built-in exercise the sender re-measured is a clash too', () async {
      // Their gym's bench sits on a 15 kg bar; mine is on the default.
      final sender = memoryDb();
      addTearDown(sender.close);
      final bench = (await _exerciseNamed(sender, 'Bench Press'))!;
      await sender.setExerciseBarWeight(bench.id, 15);
      final routineId = await sender.createRoutine(
          name: 'Theirs', color: 'FF6A3D', restSeconds: 90);
      await sender.replaceRoutineWorkouts(routineId, [
        (
          id: null,
          name: 'Day',
          items: [
            WorkoutItemsCompanion.insert(
              workoutId: 0,
              exerciseId: bench.id,
            ),
          ],
        ),
      ]);
      final shared = await sender.sharedRoutine(routineId);

      final arrivals = planExerciseArrivals(
          shared.exercises, await db.watchExercises().first);
      expect(arrivals.single.clashes, isTrue,
          reason: "their bar weight is a change to my library, so it must ask");

      await db.importSharedRoutine(shared, replace: {0});
      final mine = (await _exerciseNamed(db, 'Bench Press'))!;
      expect(mine.barWeight, 15);
      expect(mine.isCustom, isFalse,
          reason: 'a starter exercise stays a starter exercise');
    });

    test('my own note on a movement is never overwritten by an import',
        () async {
      // A personal note is the seat number at *my* gym. It is not in the code
      // the sender built, and Replace — which rewrites everything else about
      // the exercise — must still leave it alone.
      final bench = (await _exerciseNamed(db, 'Bench Press'))!;
      await db.setExerciseNotes(bench.id, 'Rack pin 7, bench squeaks');

      final sender = memoryDb();
      addTearDown(sender.close);
      final senderBench = (await _exerciseNamed(sender, 'Bench Press'))!;
      await sender.setExerciseBarWeight(senderBench.id, 15);
      final routineId = await sender.createRoutine(
        name: 'Theirs',
        color: 'FF6A3D',
        restSeconds: 60,
      );
      await sender.replaceRoutineWorkouts(routineId, [
        (
          id: null,
          name: 'Day',
          items: [
            WorkoutItemsCompanion.insert(
              workoutId: 0,
              exerciseId: senderBench.id,
            ),
          ],
        ),
      ]);
      final shared = await sender.sharedRoutine(routineId);

      await db.importSharedRoutine(shared, replace: {0});

      final mine = (await _exerciseNamed(db, 'Bench Press'))!;
      expect(mine.barWeight, 15, reason: 'Replace did rewrite the definition');
      expect(mine.notes, 'Rack pin 7, bench squeaks');
    });

    test('a note never leaves the phone in a shared routine', () async {
      final bench = (await _exerciseNamed(db, 'Bench Press'))!;
      await db.setExerciseNotes(bench.id, 'Rack pin 7');
      final shared = await db.sharedRoutine(await _seedCustomRoutine(db));

      final code = RoutineCode.encode(shared);
      expect(code.contains('Rack pin 7'), isFalse);

      // And the note is absent from what a recipient would create, too.
      final receiver = memoryDb();
      addTearDown(receiver.close);
      final decoded = RoutineCode.decode(code) as RoutineCodeOk;
      await receiver.importSharedRoutine(decoded.routine);
      for (final e in await receiver.watchExercises().first) {
        expect(e.notes, isNull, reason: '${e.name} arrived carrying a note');
      }
    });

    test('an identical exercise is no clash at all', () async {
      final sender = memoryDb();
      addTearDown(sender.close);
      final shared = await sender
          .sharedRoutine((await _routineNamed(sender, 'Upper / Lower')).id);

      final arrivals = planExerciseArrivals(
          shared.exercises, await db.watchExercises().first);
      expect(arrivals.where((a) => a.clashes), isEmpty);
      expect(arrivals.where((a) => a.isNew), isEmpty);
    });
  });

  group('links', () {
    test('a routine link opens the routine import screen', () async {
      final shared = await db.sharedRoutine(await _seedCustomRoutine(db));
      final route = routeForLink(Uri.parse(RoutineCode.link(shared)));

      expect(route, isNotNull);
      expect(route, startsWith('/routine/import?code='));
      final code = Uri.parse(route!).queryParameters['code']!;
      expect(RoutineCode.decode(code), isA<RoutineCodeOk>());
    });

    test('a theme link still goes to the theme import', () {
      final route = routeForLink(Uri.parse(ThemeCode.link(kDefaultPalette)));
      expect(route, startsWith('/settings/theme/import?code='));
    });

    test('anything else is ignored', () {
      for (final uri in [
        'https://example.com/routine/FLR1.abc',
        'fosslift://elsewhere/FLR1.abc',
        'fosslift://routine/',
      ]) {
        expect(routeForLink(Uri.parse(uri)), isNull, reason: uri);
      }
    });
  });

  group('the screens', () {
    testWidgets('sharing a routine offers a QR and a link, and nothing else',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final id = (await tester.runAsync(() => _seedCustomRoutine(db)))!;

      await tester
          .pumpWidget(appUnder(container, RoutineShareScreen(routineId: id)));
      await tester.pumpAndSettle();

      expect(find.text('Elbow Day'), findsWidgets);
      // The QR is drawn as large as the screen allows, so the actions sit below
      // the fold — scroll to each rather than asserting on what happens to be
      // built.
      for (final label in ['Show QR', 'Send link']) {
        await tester.scrollUntilVisible(find.text(label), 120,
            scrollable: find.byType(Scrollable).first);
        expect(find.text(label), findsOneWidget);
      }
      // The share sheet already offers "copy", and a file saved beside the app
      // is a code you then have to go and find. Both are gone.
      expect(find.text('Copy code'), findsNothing);
      expect(find.text('Save file'), findsNothing);

      await stop(tester);
    });

    testWidgets('an import is previewed and accepted, never applied on arrival',
        (tester) async {
      final code = (await tester.runAsync(() async {
        final sender = memoryDb();
        addTearDown(sender.close);
        return RoutineCode.encode(
            await sender.sharedRoutine(await _seedCustomRoutine(sender)));
      }))!;

      final container = containerFor(db);
      addTearDown(container.dispose);
      // Everything the import writes is read back through the providers: the
      // write happens inside the widget's own async zone, which only advances
      // as frames are pumped, so awaiting the database directly from here would
      // wait on a transaction that cannot make progress.
      final routines = container.listen(routinesProvider, (_, _) {});
      addTearDown(routines.close);

      await tester
          .pumpWidget(appUnder(container, RoutineImportScreen(code: code)));
      await tester.pumpAndSettle();
      await pumpUntil(tester, () => routines.read().value != null);
      final before = routines.read().value!.length;

      expect(find.text('Elbow Day'), findsWidgets);
      expect(find.textContaining('Zerchers'), findsWidgets);
      expect(routines.read().value!.length, before,
          reason: 'nothing is written until the user says so');

      await tester.tap(find.text('Add this routine'));
      await pumpUntil(
          tester, () => (routines.read().value?.length ?? 0) > before,
          maxFrames: 200);

      final after = routines.read().value!;
      expect(after.length, before + 1);
      expect(after.map((r) => r.routine.name), contains('Elbow Day'));

      await stop(tester);
    });

    testWidgets('a clash is shown with a switch, off by default',
        (tester) async {
      final code = (await tester.runAsync(() async {
        await db.createExercise(
          name: 'Zercher Squat',
          muscle: 'Other',
          equipment: 'Machine',
        );
        final sender = memoryDb();
        addTearDown(sender.close);
        return RoutineCode.encode(
            await sender.sharedRoutine(await _seedCustomRoutine(sender)));
      }))!;

      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester
          .pumpWidget(appUnder(container, RoutineImportScreen(code: code)));
      await tester.pumpAndSettle();

      expect(find.text('Zercher Squat'), findsWidgets);
      final switches = find.byType(Switch);
      expect(switches, findsOneWidget);
      expect(tester.widget<Switch>(switches).value, isFalse,
          reason: 'keeping what I already have is the default');

      final routines = container.listen(routinesProvider, (_, _) {});
      addTearDown(routines.close);
      await pumpUntil(tester, () => routines.read().value != null);
      final before = routines.read().value!.length;

      await tester.tap(find.text('Add this routine'));
      await pumpUntil(
          tester, () => (routines.read().value?.length ?? 0) > before,
          maxFrames: 200);

      final library = container.read(exerciseLibraryProvider).value!;
      final mine = library.firstWhere((e) => e.name == 'Zercher Squat');
      expect(mine.equipment, 'Machine',
          reason: 'the switch was left off, so my definition stands');
      expect(library.where((e) => e.name == 'Zercher Squat'), hasLength(1));

      await stop(tester);
    });

    testWidgets('a damaged code explains itself and offers nothing to apply',
        (tester) async {
      final code = (await tester.runAsync(() async =>
          RoutineCode.encode(await db.sharedRoutine(await _seedCustomRoutine(db)))))!;
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container,
          RoutineImportScreen(code: code.substring(0, code.length - 6))));
      await tester.pumpAndSettle();

      expect(find.textContaining('characters missing'), findsOneWidget);
      expect(find.text('Add this routine'), findsNothing,
          reason: 'there is nothing safe to add');

      await stop(tester);
    });
  });
}
