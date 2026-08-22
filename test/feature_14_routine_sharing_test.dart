// Integration tests for encoding, previewing, importing, and sharing routines (features/index.html#sec14).

import 'dart:io';

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
import 'package:foss_lift/widgets/share_widgets.dart';
import 'package:foss_lift/services/deep_links.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/theme/theme_code.dart';
import 'package:foss_lift/util/qr_capacity.dart';
import 'package:foss_lift/util/seed_names.dart';
import 'package:foss_lift/util/units.dart';
import 'package:foss_lift/util/video_links.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'support/harness.dart';
import 'support/seeded.dart';
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

/// A genuine FLR1 code, written by the shipped build for the routine
/// [_seedCustomRoutine] makes. This is the code in last month's chat message: it
/// is not regenerated, because the point of it is that it was written by a build
/// that is gone — one that had never heard of a superset, among other things.
const _shippedFlr1 =
    'FLR1.AeN0zUnKL1dwSay0uzrjEiMXozBvVGpRckZqkUJwYWliCQ'
    'sjd6JTsouhkbFJvG7FHW5GDqh0MSPDdH42ZtYPjF-YH3EyswAAtQBW9Q';

/// A shipped program, looked up by name and added from the routine library if
/// this database has not got it — the routine list starts empty. Ids are an
/// implementation detail either way.
Future<Routine> _routineNamed(AppDatabase db, String name) =>
    routineNamed(db, name);

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
    muscles: MuscleMap.single('Legs'),
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
      expect(
        back.scheduleDays,
        ppl.scheduleDays,
        reason: 'the training days are part of the programme',
      );
      expect(back.workouts.map((w) => w.name), ['Push', 'Pull', 'Legs']);
      expect(back.workouts.map((w) => w.items.length), [5, 5, 5]);

      final bench = back.workouts.first.items.first;
      expect(back.exercises[bench.exercise].name, 'Bench Press');
      expect(bench.targetSets, 4);
      expect(bench.repsMin, 6);
      expect(bench.repsMax, 8);
      expect(bench.progression, ProgressionMode.weight);

      // A pull-up: no load, so the seed puts it on the reps axis with that
      // mode's own increment rather than the weight-mode default.
      final pullUp = back.workouts[1].items[1];
      expect(back.exercises[pullUp.exercise].name, 'Pull-Up');
      expect(pullUp.progression, ProgressionMode.reps);
      expect(pullUp.increment, ProgressionMode.reps.defaultIncrement);
    });

    test('a set scheme travels as a shape, not as weights', () async {
      final squat = await exerciseNamed(db, 'Back Squat');
      final rid = await db.createRoutine(
        name: 'Ladders',
        color: 'FF0000',
        restSeconds: 90,
      );
      final wid = await db.createWorkout(rid, 'Day');
      await db.replaceWorkoutItems(
        wid,
        itemCompanions([
          ItemDraft.forExercise(squat)
            ..sets = 3
            ..weightKg = 100
            ..scheme = SetScheme.backOff
            ..schemePercent = 15,
          ItemDraft.forExercise(squat)
            ..sets = 2
            ..scheme = SetScheme.custom
            ..customSets = const [
              CustomSet(reps: 5, percent: 100),
              CustomSet(reps: 10, percent: 70),
            ],
        ], workoutId: wid),
      );

      final back =
          (RoutineCode.decode(RoutineCode.encode(await db.sharedRoutine(rid)))
                  as RoutineCodeOk)
              .routine;
      final slots = back.workouts.single.items;

      expect(slots.first.scheme, SetScheme.backOff);
      expect(slots.first.schemePercent, 15);
      expect(slots[1].scheme, SetScheme.custom);
      expect(slots[1].customSets, const [
        CustomSet(reps: 5, percent: 100),
        CustomSet(reps: 10, percent: 70),
      ]);
    });

    test('a flat slot spends no bytes saying so', () async {
      final plain = SharedItem(exercise: 0);
      expect(plain.scheme, SetScheme.flat);
      expect(plain.customSets, isEmpty);
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
      expect(slot.increment, 5);
      expect(slot.deload, 12.5);
      expect(slot.successThreshold, 3);
      expect(slot.failureThreshold, 4);
    });

    test('the weight is not on the wire at all', () async {
      final routineId = await _seedCustomRoutine(db);
      final before = RoutineCode.encode(await db.sharedRoutine(routineId));

      // The same routine, with the one thing that is personal changed.
      final day = (await db.workoutsForRoutine(routineId)).single;
      final slot = (await db.itemsForWorkout(day.id)).single.item;
      await db.replaceWorkoutItems(day.id, [
        slot
            .toCompanion(false)
            .copyWith(
              id: const Value.absent(),
              suggestedWeight: const Value(60),
            ),
      ]);

      expect(
        RoutineCode.encode(await db.sharedRoutine(routineId)),
        before,
        reason: 'someone else\'s working weight is not part of the program',
      );
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

    test(
      'a custom exercise travels in full; a built-in travels by name',
      () async {
        final custom = await db.sharedRoutine(await _seedCustomRoutine(db));
        final theirs =
            (RoutineCode.decode(RoutineCode.encode(custom)) as RoutineCodeOk)
                .routine
                .exercises
                .single;

        expect(theirs.name, 'Zercher Squat');
        expect(theirs.isCustom, isTrue);
        expect(theirs.muscles.primary, ['Legs']);
        expect(theirs.muscles.secondary, isEmpty);
        expect(theirs.equipment, 'Barbell');
        expect(theirs.weightType, WeightType.bar);
        expect(
          theirs.barWeight,
          15,
          reason: "the sender's bar for this movement is part of the exercise",
        );
        // The link travels as its video id and comes back canonical: the
        // timestamp, the tracking parameters and the www. are all noise.
        expect(theirs.videoUrl, 'https://youtu.be/aBcD1234_-x');

        // A starter-library movement is on both phones already, so it travels by
        // name rather than in full.
        final ppl = await db.sharedRoutine(
          (await _routineNamed(db, 'Push / Pull / Legs')).id,
        );
        final builtIn =
            (RoutineCode.decode(RoutineCode.encode(ppl)) as RoutineCodeOk)
                .routine
                .exercises
                .firstWhere((e) => e.name == 'Bench Press');
        expect(builtIn.isCustom, isFalse);
        // Its demo does travel, though — eleven characters of video id. It used
        // to be a YouTube *search*, which has no video behind it to name, so a
        // starter movement arrived with no demo at all.
        expect(
          youTubeVideoId(builtIn.videoUrl ?? ''),
          isNotNull,
          reason: 'a starter demo is a real video and rides along',
        );
        expect(builtIn.videoUrl, startsWith('https://youtu.be/'));
      },
    );

    test('the sender\'s streaks and reminder stay behind', () async {
      final shared = await db.sharedRoutine(await _seedCustomRoutine(db));
      final code = RoutineCode.encode(shared);

      final fresh = memoryDb();
      addTearDown(fresh.close);
      final newId = await fresh.importSharedRoutine(
        (RoutineCode.decode(code) as RoutineCodeOk).routine,
      );
      final routine = await fresh.routineById(newId);
      expect(
        routine.reminderMinutes,
        isNull,
        reason: 'a notification is asked for, never inherited',
      );
      expect(routine.scheduleDays, 1 << 1 | 1 << 3);

      final workout = (await fresh.workoutsForRoutine(newId)).single;
      final item = (await fresh.itemsForWorkout(workout.id)).single.item;
      expect(item.successStreak, 0);
      expect(item.failStreak, 0);
      expect(
        item.suggestedWeight,
        isNull,
        reason:
            'a phone that has never trained the movement has no weight '
            'to put on it',
      );
    });

    test('an ordinary routine is small enough for a QR code', () async {
      final ppl = await db.sharedRoutine(
        (await _routineNamed(db, 'Push / Pull / Legs')).id,
      );
      final link = RoutineCode.link(ppl);

      expect(
        RoutineCode.fitsQr(link),
        isTrue,
        reason: 'the demo routine must be shareable as a QR',
      );
      expect(link.length, lessThan(RoutineCode.qrLinkLimit));
      expect(
        qrEccFor(link.length),
        QrEcc.medium,
        reason: 'and with room to spare for error correction',
      );
    });

    test('and still is once every starter carries a real video id', () async {
      // The starter library's demo links are YouTube *searches* today, so
      // `youTubeVideoId` finds nothing in them and no id travels (#43). When
      // they are replaced with real videos, eleven characters per exercise
      // start riding along inside every routine that uses one — which is the
      // question worth answering before doing the work, not after.
      //
      // Id-shaped, not real: this measures what the wire format costs, and that
      // does not depend on the ids pointing anywhere.
      var n = 0;
      for (final e in await db.watchExercises().first) {
        await (db.update(db.exercises)..where((t) => t.id.equals(e.id))).write(
          ExercisesCompanion(videoUrl: Value(youTubeUrl(_noise(n++, 11)))),
        );
      }

      final ppl = await db.sharedRoutine(
        (await _routineNamed(db, 'Push / Pull / Legs')).id,
      );
      final link = RoutineCode.link(ppl);

      expect(
        RoutineCode.fitsQr(link),
        isTrue,
        reason: 'real demo links must not cost the demo routine its QR',
      );
      expect(
        qrEccFor(link.length),
        QrEcc.medium,
        reason: 'and not cost it its error correction either',
      );
    });

    test(
      'a routine too big for any QR says so rather than painting one',
      () async {
        // With cues gone, names are the only field a person can make long enough
        // to run a routine past a version-40 symbol — and it takes sixty of them
        // at the full length, in text that will not compress.
        final routineId = await db.createRoutine(
          name: 'Everything',
          color: 'FF6A3D',
          restSeconds: 90,
        );
        final items = <WorkoutItemsCompanion>[];
        for (var i = 0; i < 60; i++) {
          final id = await db.createExercise(
            name: _noise(i, 80),
            muscles: MuscleMap.single('Other'),
            equipment: 'Machine',
          );
          items.add(
            WorkoutItemsCompanion.insert(
              workoutId: 0,
              exerciseId: id,
              position: Value(i),
            ),
          );
        }
        await db.replaceRoutineWorkouts(routineId, [
          (id: null, name: 'All of it', items: items),
        ]);

        final link = RoutineCode.link(await db.sharedRoutine(routineId));
        expect(
          link.length,
          greaterThan(RoutineCode.qrLinkLimit),
          reason: 'this is the case the QR limit exists for',
        );
        expect(RoutineCode.fitsQr(link), isFalse);
        expect(qrEccFor(link.length), isNull);

        // Still perfectly shareable as a pasted code — the code itself is fine.
        expect(
          (RoutineCode.decode(link) as RoutineCodeOk).routine.exercises,
          hasLength(60),
        );
      },
    );

    test('a big routine spends its error correction to stay scannable', () {
      // Between the two capacities a symbol is still worth painting, just with
      // less redundancy — a worse QR beats no QR when the fallback is a paste.
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
      expect(
        plainCode.length,
        lessThan(loudCode.length),
        reason: 'a slot left at its defaults must not be spelled out',
      );
    });
  });

  group('a routine\'s description travels with it', () {
    /// A one-day routine carrying [description], as it comes off the wire.
    Future<SharedRoutine> roundTrip(String? description) async {
      final plank = (await _exerciseNamed(db, 'Plank'))!;
      final rid = await db.createRoutine(
        name: 'Described',
        color: 'FF6A3D',
        restSeconds: 90,
        description: description,
      );
      await db.replaceRoutineWorkouts(rid, [
        (
          id: null,
          name: 'Day',
          items: [
            WorkoutItemsCompanion.insert(workoutId: 0, exerciseId: plank.id),
          ],
        ),
      ]);
      final code = RoutineCode.encode(await db.sharedRoutine(rid));
      final read = RoutineCode.decode(code);
      expect(read, isA<RoutineCodeOk>());
      return (read as RoutineCodeOk).routine;
    }

    test('the sender\'s paragraph arrives as they wrote it', () async {
      const text = 'Four days a week: two heavy, two for volume. Bring chalk.';
      expect((await roundTrip(text)).description, text);
    });

    test('a routine with nothing to say arrives with nothing', () async {
      expect((await roundTrip(null)).description, isNull);
      expect(
        (await roundTrip('   ')).description,
        isNull,
        reason: 'whitespace is not a description',
      );
    });

    test('and costs nothing at all for saying so', () async {
      final plank = (await _exerciseNamed(db, 'Plank'))!;
      final rid = await db.createRoutine(
        name: 'Described',
        color: 'FF6A3D',
        restSeconds: 90,
      );
      await db.replaceRoutineWorkouts(rid, [
        (
          id: null,
          name: 'Day',
          items: [
            WorkoutItemsCompanion.insert(workoutId: 0, exerciseId: plank.id),
          ],
        ),
      ]);
      final plain = await db.sharedRoutine(rid);

      /// The same routine, with [description] on it.
      String codeWith(String? description) => RoutineCode.encode(
        SharedRoutine(
          name: plain.name,
          colorHex: plain.colorHex,
          restSeconds: plain.restSeconds,
          scheduleDays: plain.scheduleDays,
          description: description,
          exercises: plain.exercises,
          workouts: plain.workouts,
        ),
      );

      expect(plain.description, isNull);
      expect(codeWith(null), RoutineCode.encode(plain));
      expect(
        codeWith('   '),
        RoutineCode.encode(plain),
        reason: 'whitespace buys no field either',
      );
      expect(
        codeWith('A paragraph, which is the only thing paid for.').length,
        greaterThan(RoutineCode.encode(plain).length),
      );
    });

    test(
      'a description longer than the format carries is cut, not refused',
      () async {
        final long = 'Z' * (RoutineCode.maxDescriptionBytes + 500);
        final plain = await roundTrip('short');
        final oversized = SharedRoutine(
          name: plain.name,
          colorHex: plain.colorHex,
          restSeconds: plain.restSeconds,
          scheduleDays: plain.scheduleDays,
          description: long,
          exercises: plain.exercises,
          workouts: plain.workouts,
        );

        final back =
            (RoutineCode.decode(RoutineCode.encode(oversized)) as RoutineCodeOk)
                .routine;
        expect(
          back.description,
          hasLength(RoutineCode.maxDescriptionBytes),
          reason: 'cut to the limit rather than failing the whole export',
        );
        expect(
          RoutineCode.maxDescriptionBytes,
          greaterThan(300),
          reason: 'generous next to the 300 characters the app enforces',
        );
      },
    );

    test('an import lands the description on the new routine', () async {
      const text = 'Two sessions a week, whole body in each.';
      final shared = await roundTrip(text);

      final id = await db.importSharedRoutine(shared);

      expect((await db.routineById(id)).description, text);
    });

    test('an imported program is nobody\'s copy of a shipped one', () async {
      final ppl = await _routineNamed(db, 'Push / Pull / Legs');
      final shared = await db.sharedRoutine(ppl.id);
      expect(
        shared.description,
        isNotNull,
        reason: 'the library program it came from describes itself',
      );

      final id = await db.importSharedRoutine(shared);
      final landed = await db.routineById(id);

      expect(landed.description, shared.description);
      expect(landed.seedKey, isNull);
      expect(
        seededDescription(
          l10nFor(const Locale('uk')),
          landed.seedKey,
          landed.description,
        ),
        landed.description,
        reason: 'an import shows the words it arrived with',
      );
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
        name: 'Fine',
        color: 'FF6A3D',
        restSeconds: 90,
      );
      await db.replaceRoutineWorkouts(routineId, [
        (
          id: null,
          name: long.substring(0, 80),
          items: [
            WorkoutItemsCompanion.insert(
              workoutId: 0,
              exerciseId: (await _exerciseNamed(db, 'Plank'))!.id,
            ),
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

      final back =
          (RoutineCode.decode(RoutineCode.encode(oversized)) as RoutineCodeOk)
              .routine;
      expect(
        back.name.length,
        RoutineCode.maxNameBytes,
        reason: 'cut to the limit rather than failing the whole export',
      );
      expect(back.name, long.substring(0, RoutineCode.maxNameBytes));
    });

    test('a name limit generous enough that nobody meets it', () {
      // The database stops at 80; the wire format leaves room above that so a
      // future longer name never silently loses characters here first.
      expect(RoutineCode.maxNameBytes, greaterThan(80));
    });
  });

  group('the whole muscle map travels, and an FLR1 code still opens', () {
    /// A routine of one movement carrying [map], as it arrives on the far end.
    Future<SharedExercise> roundTrip(MuscleMap map) async {
      final sender = memoryDb();
      addTearDown(sender.close);
      final id = await sender.createExercise(
        name: 'Zercher Squat',
        muscles: map,
        equipment: 'Barbell',
        weightType: WeightType.bar,
      );
      final routineId = await sender.createRoutine(
        name: 'Elbow Day',
        color: '3ED598',
        restSeconds: 90,
      );
      await sender.replaceRoutineWorkouts(routineId, [
        (
          id: null,
          name: 'Zerchers',
          items: [WorkoutItemsCompanion.insert(workoutId: 0, exerciseId: id)],
        ),
      ]);
      final code = RoutineCode.encode(await sender.sharedRoutine(routineId));
      return (RoutineCode.decode(code) as RoutineCodeOk)
          .routine
          .exercises
          .single;
    }

    test(
      'every group a movement trains and assists survives the trip',
      () async {
        final theirs = await roundTrip(
          MuscleMap(primary: ['Legs', 'Core'], secondary: ['Back', 'Arms']),
        );

        expect(theirs.muscles.primary, ['Legs', 'Core']);
        expect(theirs.muscles.secondary, ['Back', 'Arms']);
        expect(theirs.muscles.lead, 'Legs');
      },
    );

    test('including a group the recipient has never heard of', () async {
      // An unknown word costs the code its own length rather than the whole
      // exercise, exactly as the lead already did.
      final theirs = await roundTrip(
        MuscleMap(primary: ['Legs', 'Forearms'], secondary: ['Grip']),
      );

      expect(theirs.muscles.primary, ['Legs', 'Forearms']);
      expect(theirs.muscles.secondary, ['Grip']);
    });

    test('and it lands on the recipient as the same map', () async {
      final sender = memoryDb();
      addTearDown(sender.close);
      final id = await sender.createExercise(
        name: 'Zercher Squat',
        muscles: MuscleMap(primary: ['Legs', 'Core'], secondary: ['Back']),
        equipment: 'Barbell',
      );
      final routineId = await sender.createRoutine(
        name: 'Elbow Day',
        color: '3ED598',
        restSeconds: 90,
      );
      await sender.replaceRoutineWorkouts(routineId, [
        (
          id: null,
          name: 'Zerchers',
          items: [WorkoutItemsCompanion.insert(workoutId: 0, exerciseId: id)],
        ),
      ]);

      await db.importSharedRoutine(await sender.sharedRoutine(routineId));

      final landed = (await _exerciseNamed(db, 'Zercher Squat'))!;
      expect(landed.muscles.primary, ['Legs', 'Core']);
      expect(landed.muscles.secondary, ['Back']);
      expect(landed.muscleGroup, 'Legs');
    });

    test('an FLR1 code arrives with one primary and no secondaries', () {
      final result = RoutineCode.decode(_shippedFlr1);

      expect(
        result,
        isA<RoutineCodeOk>(),
        reason: 'a code somebody is still holding has to keep opening',
      );
      final routine = (result as RoutineCodeOk).routine;
      expect(routine.name, 'Elbow Day');
      final theirs = routine.exercises.single;
      expect(theirs.name, 'Zercher Squat');
      expect(
        theirs.muscles.primary,
        ['Legs'],
        reason: 'the single group it was written with, which is what it meant',
      );
      expect(theirs.muscles.secondary, isEmpty);
    });

    test('a phone that only reads FLR1 refuses an FLR2 code', () async {
      // The other direction does not work, and says so plainly rather than
      // importing a mangled routine.
      final code = RoutineCode.encode(
        await db.sharedRoutine(await _seedCustomRoutine(db)),
      );

      final read = ShareCodec.unpack(
        code,
        versions: {'FLR1'},
        host: RoutineCode.host,
        minBody: 2,
        checksumBytes: 4,
      );

      expect(read.body, isNull);
      expect(read.problem, ShareCodeProblem.notACode);
      expect(read.version, isNull);
    });

    test('and this build reads both, saying which one it read', () async {
      final flr2 = RoutineCode.encode(
        await db.sharedRoutine(await _seedCustomRoutine(db)),
      );

      for (final (code, version) in [(_shippedFlr1, 'FLR1'), (flr2, 'FLR2')]) {
        final read = ShareCodec.unpack(
          code,
          versions: {'FLR1', 'FLR2'},
          host: RoutineCode.host,
          minBody: 2,
          checksumBytes: 4,
        );
        expect(read.problem, isNull, reason: 'reading a $version code');
        expect(read.version, version);
        expect(read.body, isNotNull);
      }
    });

    test('a single-group routine costs FLR2 nothing over FLR1', () async {
      // The muscle bit is only written when there is something beyond the
      // lead, so the body is the same bytes and only the tag differs.
      final code = RoutineCode.encode(
        await db.sharedRoutine(await _seedCustomRoutine(db)),
      );

      expect(code.length, _shippedFlr1.length);
      expect(
        code.substring('FLR2.'.length),
        _shippedFlr1.substring('FLR1.'.length),
        reason: 'byte-identical to what FLR1 wrote, apart from the tag',
      );
    });
  });

  group('a shared routine carries its supersets', () {
    /// A two-slot day on the *sender's* phone, the second slot [joined] to the
    /// first or not, gathered into the shape the wire format takes.
    Future<SharedRoutine> twoSlotRoutine({required bool joined}) async {
      final sender = memoryDb();
      addTearDown(sender.close);
      final rid = await sender.createRoutine(
        name: 'Giant Set',
        color: 'FF0000',
        restSeconds: 90,
      );
      final wid = await sender.createWorkout(rid, 'Day');
      await sender.replaceWorkoutItems(
        wid,
        itemCompanions([
          ItemDraft.forExercise(await exerciseNamed(sender, 'Bench Press')),
          ItemDraft.forExercise(await exerciseNamed(sender, 'Overhead Press'))
            ..supersetWithPrevious = joined,
        ], workoutId: wid),
      );
      return sender.sharedRoutine(rid);
    }

    test('the joins survive the trip, and the tag stays FLR2', () async {
      final code = RoutineCode.encode(await twoSlotRoutine(joined: true));
      expect(
        code,
        startsWith('FLR2.'),
        reason: 'the joins ride after the days, not inside a slot',
      );

      final result = RoutineCode.decode(code);
      expect(result, isA<RoutineCodeOk>());
      final back = (result as RoutineCodeOk).routine;

      expect(back.workouts.single.items.map((i) => i.supersetWithPrevious), [
        false,
        true,
      ]);
      // And it lands on the recipient as the same pair.
      await db.importSharedRoutine(back);
      final landed = await _routineNamed(db, 'Giant Set');
      final day = (await db.workoutsForRoutine(landed.id)).single;
      expect(
        (await db.itemsForWorkout(
          day.id,
        )).map((v) => v.item.supersetWithPrevious),
        [false, true],
      );
    });

    test('a routine with none in it is no longer than it was before', () async {
      // The section is written only when something is joined, so a joinless
      // routine is the same bytes the shipped build wrote — see [_shippedFlr1],
      // which is a code for exactly this routine from a build that had never
      // heard of a superset.
      final code = RoutineCode.encode(
        await db.sharedRoutine(await _seedCustomRoutine(db)),
      );

      expect(code.length, _shippedFlr1.length);
      expect(
        code.substring('FLR2.'.length),
        _shippedFlr1.substring('FLR1.'.length),
      );

      // The same two-slot day pays nothing for the feature either, and reads
      // back with every slot standing on its own.
      final plain = RoutineCode.encode(await twoSlotRoutine(joined: false));
      final back = (RoutineCode.decode(plain) as RoutineCodeOk).routine;
      expect(back.workouts.single.items.map((i) => i.supersetWithPrevious), [
        false,
        false,
      ]);
    });

    test(
      'a code written before the section decodes with nothing joined',
      () async {
        final result = RoutineCode.decode(_shippedFlr1);

        expect(result, isA<RoutineCodeOk>());
        final back = (result as RoutineCodeOk).routine;
        expect(
          back.workouts
              .expand((w) => w.items)
              .map((i) => i.supersetWithPrevious),
          everyElement(isFalse),
          reason: 'what a code does not carry is taken as absent',
        );
      },
    );
  });

  group('a shared routine carries which slots climb their range', () {
    /// A two-slot day on the *sender's* phone: a ranged Bench Press ticked to
    /// add weight at the top of its range when [climbs], and an Overhead Press
    /// that is an ordinary slot either way.
    Future<SharedRoutine> rangedRoutine({required bool climbs}) async {
      final sender = memoryDb();
      addTearDown(sender.close);
      final rid = await sender.createRoutine(
        name: 'Double Up',
        color: 'FF0000',
        restSeconds: 90,
      );
      final wid = await sender.createWorkout(rid, 'Day');
      await sender.replaceWorkoutItems(
        wid,
        itemCompanions([
          ItemDraft.forExercise(await exerciseNamed(sender, 'Bench Press'))
            ..repsMin = 6
            ..repsMax = 8
            ..addWeightAtTopOfRange = climbs,
          ItemDraft.forExercise(await exerciseNamed(sender, 'Overhead Press')),
        ], workoutId: wid),
      );
      return sender.sharedRoutine(rid);
    }

    test('the ticks survive the trip, and the tag stays FLR2', () async {
      final code = RoutineCode.encode(await rangedRoutine(climbs: true));
      expect(
        code,
        startsWith('FLR2.'),
        reason: 'the ticks ride after the days, not inside a slot',
      );

      final result = RoutineCode.decode(code);
      expect(result, isA<RoutineCodeOk>());
      final back = (result as RoutineCodeOk).routine;
      expect(back.workouts.single.items.map((i) => i.addWeightAtTopOfRange), [
        true,
        false,
      ]);

      // And it lands on the recipient as the same program.
      await db.importSharedRoutine(back);
      final landed = await _routineNamed(db, 'Double Up');
      final day = (await db.workoutsForRoutine(landed.id)).single;
      final items = await db.itemsForWorkout(day.id);
      expect(items.map((v) => v.item.addWeightAtTopOfRange), [true, false]);
      expect(items.first.item.repsMax, 8, reason: 'the range it climbs');
    });

    test(
      'a routine where nothing climbs a range costs no bytes at all',
      () async {
        // The section is written only when there is a tick to carry, so a routine
        // without one is the same bytes the shipped build wrote — see
        // [_shippedFlr1], a code for exactly this routine from a build that had
        // never heard of the tick.
        final code = RoutineCode.encode(
          await db.sharedRoutine(await _seedCustomRoutine(db)),
        );

        expect(code.length, _shippedFlr1.length);
        expect(
          code.substring('FLR2.'.length),
          _shippedFlr1.substring('FLR1.'.length),
        );

        // The same two-slot day pays nothing for the feature either.
        final plain = RoutineCode.encode(await rangedRoutine(climbs: false));
        final back = (RoutineCode.decode(plain) as RoutineCodeOk).routine;
        expect(back.workouts.single.items.map((i) => i.addWeightAtTopOfRange), [
          false,
          false,
        ]);
      },
    );

    test(
      'a code written before the section decodes with nothing ticked',
      () async {
        final result = RoutineCode.decode(_shippedFlr1);

        expect(result, isA<RoutineCodeOk>());
        final back = (result as RoutineCodeOk).routine;
        expect(
          back.workouts
              .expand((w) => w.items)
              .map((i) => i.addWeightAtTopOfRange),
          everyElement(isFalse),
          reason:
              'a program that adds weight a session sooner, not a corrupt one',
        );
      },
    );
  });

  group('a shared routine carries its GZCL configuration', () {
    test(
      'tiers and custom rules travel, while the current stage starts over',
      () async {
        final sender = memoryDb();
        addTearDown(sender.close);
        final rid = await sender.createRoutine(
          name: 'GZCL custom',
          color: 'FF0000',
          restSeconds: 90,
        );
        final wid = await sender.createWorkout(rid, 'Day');
        final bench =
            ItemDraft.forExercise(await exerciseNamed(sender, 'Bench Press'))
              ..gzclTier = GzclTier.t1
              ..gzclStages = const [
                GzclStage(sets: 5, reps: 5),
                GzclStage(sets: 5, reps: 3),
                GzclStage(sets: 6, reps: 2),
                GzclStage(sets: 10, reps: 1),
              ]
              ..gzclStage = 2;
        final row =
            ItemDraft.forExercise(await exerciseNamed(sender, 'Dumbbell Row'))
              ..gzclTier = GzclTier.t3
              ..gzclAmrapTarget = 20;
        await sender.replaceWorkoutItems(
          wid,
          itemCompanions([bench, row], workoutId: wid),
        );

        final code = RoutineCode.encode(await sender.sharedRoutine(rid));
        final decoded = (RoutineCode.decode(code) as RoutineCodeOk).routine;
        final sharedItems = decoded.workouts.single.items;
        expect(sharedItems.first.gzclTier, GzclTier.t1);
        expect(sharedItems.first.gzclStages, bench.gzclStages);
        expect(sharedItems.last.gzclTier, GzclTier.t3);
        expect(sharedItems.last.gzclAmrapTarget, 20);

        final importedId = await db.importSharedRoutine(decoded);
        final importedDay = (await db.workoutsForRoutine(importedId)).single;
        final landed = await db.itemsForWorkout(importedDay.id);
        expect(landed.first.item.gzclTier, GzclTier.t1);
        expect(landed.first.item.gzclStageList, bench.gzclStages);
        expect(
          landed.first.item.gzclStage,
          0,
          reason: 'progress belongs to the sender',
        );
        expect(landed.last.item.gzclTier, GzclTier.t3);
        expect(landed.last.item.gzclAmrapTarget, 20);
      },
    );
  });

  group('the rep rates travel with the slots that use them', () {
    /// A two-slot day on the *sender's* phone: a 6–8 Bench Press on the
    /// advanced axis, stepping its goal by [repsIncrement] and backing it off
    /// by [repsDeload] and already partway up its range, plus an ordinary
    /// Overhead Press.
    Future<SharedRoutine> ratedRoutine({
      bool advanced = true,
      double repsIncrement = 2,
      double repsDeload = 3,
      int? repsTarget = 8,
    }) async {
      final sender = memoryDb();
      addTearDown(sender.close);
      final rid = await sender.createRoutine(
        name: 'Double Up',
        color: 'FF0000',
        restSeconds: 90,
      );
      final wid = await sender.createWorkout(rid, 'Day');
      final bench =
          ItemDraft.forExercise(await exerciseNamed(sender, 'Bench Press'))
            ..repsMin = 6
            ..repsMax = 8
            ..repsIncrement = repsIncrement
            ..repsDeload = repsDeload
            ..repsTarget = repsTarget;
      if (advanced) bench.setAdvanced(true);
      await sender.replaceWorkoutItems(
        wid,
        itemCompanions([
          bench,
          ItemDraft.forExercise(await exerciseNamed(sender, 'Overhead Press')),
        ], workoutId: wid),
      );
      return sender.sharedRoutine(rid);
    }

    test('the rep step and back-off survive the trip', () async {
      final code = RoutineCode.encode(await ratedRoutine());
      final back = (RoutineCode.decode(code) as RoutineCodeOk).routine;

      final climbing = back.workouts.single.items.first;
      expect(climbing.addWeightAtTopOfRange, isTrue);
      expect(climbing.repsIncrement, 2);
      expect(climbing.repsDeload, 3);

      // And they land on the recipient as the program the sender wrote.
      await db.importSharedRoutine(back);
      final landed = await _routineNamed(db, 'Double Up');
      final day = (await db.workoutsForRoutine(landed.id)).single;
      final items = await db.itemsForWorkout(day.id);
      expect(items.first.item.repsIncrement, 2);
      expect(items.first.item.repsDeload, 3);
      expect(items.first.item.repsMax, 8, reason: 'the range they move inside');
    });

    test('where the sender had got to does not travel', () async {
      // A shared routine is a program, not somebody's progress through one.
      final code = RoutineCode.encode(await ratedRoutine());
      final back = (RoutineCode.decode(code) as RoutineCodeOk).routine;
      await db.importSharedRoutine(back);

      final landed = await _routineNamed(db, 'Double Up');
      final day = (await db.workoutsForRoutine(landed.id)).single;
      final slot = (await db.itemsForWorkout(day.id)).first.item;
      expect(slot.repsTarget, isNull);
      expect(
        slot.goalReps,
        6,
        reason: 'every imported slot starts at the bottom',
      );
    });

    test('a slot that does not use them pays nothing for them', () async {
      // Only the slots taking the two axes in turn carry the pair, so rates
      // left on a slot that is not climbing cost the code nothing.
      final rated = RoutineCode.encode(await ratedRoutine(advanced: false));
      final plain = RoutineCode.encode(
        await ratedRoutine(advanced: false, repsIncrement: 1, repsDeload: 2),
      );

      expect(rated, plain);
      final back = (RoutineCode.decode(rated) as RoutineCodeOk).routine;
      expect(back.workouts.single.items.first.repsIncrement, 1);
      expect(back.workouts.single.items.first.repsDeload, 2);
    });

    test('a code written before the section imports at the defaults', () async {
      final result = RoutineCode.decode(_shippedFlr1);

      expect(result, isA<RoutineCodeOk>());
      final back = (result as RoutineCodeOk).routine;
      final items = back.workouts.expand((w) => w.items);
      expect(items.map((i) => i.repsIncrement), everyElement(1));
      expect(items.map((i) => i.repsDeload), everyElement(2));
    });
  });

  group('a code that will not read', () {
    /// Text a paste box will actually see: empty, junk, truncated, the wrong
    /// kind of code, and one carrying characters a URL treats as punctuation.
    const hostile = [
      '',
      '   ',
      'hello',
      'FLR1',
      'FLR1.',
      'FLR1.@@@@',
      'FLR1.AAAA',
      'FLT1.AAAA',
      'fosslift://routine/FLR1.AAAA',
      'code with & and # and ? in it',
      'FLR1.a+b/c=',
    ];

    Future<String> aCode() async => RoutineCode.encode(
      await db.sharedRoutine(await _seedCustomRoutine(db)),
    );

    test('nothing a paste box can hold makes the decoder throw', () {
      for (final text in hostile) {
        expect(
          () => RoutineCode.decode(text),
          returnsNormally,
          reason: 'decoding "$text"',
        );
        expect(
          () => ThemeCode.decode(text),
          returnsNormally,
          reason: 'decoding "$text" as a theme',
        );
      }
    });

    testWidgets('refusing one paints no error frame', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      for (final text in hostile) {
        await tester.pumpWidget(
          routedAppUnder(container, RoutineImportScreen(code: text)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'importing "$text"');
      }
      await stop(tester);
    });

    testWidgets('and neither does the paste box on its way out', (
      tester,
    ) async {
      // The red frames reported against an invalid code were not about the code
      // at all: promptForCode disposed its controller the moment showDialog's
      // future completed, which is when the route is *popped* — the field is
      // still mounted and still using it for the length of the dismissal.
      final container = containerFor(db);
      addTearDown(container.dispose);
      String? got;

      await tester.pumpWidget(
        appUnder(
          container,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => got = await promptForCode(
                  context,
                  title: 'Paste a routine',
                  hint: 'FLR1.…',
                ),
                child: const Text('Paste'),
              ),
            ),
          ),
        ),
      );

      // Both ways out: the one that carries the text on, and the one that
      // throws it away. Neither may paint a red frame on the way.
      for (final (ending, expected) in [
        ('Continue', 'not a code'),
        ('Cancel', null),
      ]) {
        got = null;
        await tester.tap(find.text('Paste'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'not a code');
        await tester.tap(find.text(ending));
        // Every frame of the dismissal, not just where it settles.
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          expect(
            tester.takeException(),
            isNull,
            reason: '$ending, frame $i of the dismissal',
          );
        }
        await tester.pumpAndSettle();
        expect(got, expected, reason: 'after $ending');
      }

      await stop(tester);
    });

    test('is version-tagged so a later format can be told apart', () async {
      expect(await aCode(), startsWith('FLR2.'));
    });

    test(
      'a code tagged with another format version is simply not a code',
      () async {
        final other = (await aCode()).replaceFirst('FLR2', 'FLR9');
        final result = RoutineCode.decode(other);
        expect(result, isA<RoutineCodeFailure>());
        expect(
          (result as RoutineCodeFailure).problem,
          ShareCodeProblem.notACode,
        );
      },
    );

    test(
      'text that is not a routine code at all is rejected as such',
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
          expect(
            (result as RoutineCodeFailure).problem,
            ShareCodeProblem.notACode,
            reason: 'decoding "$text"',
          );
        }
      },
    );

    test(
      'a truncated code is caught rather than importing half a routine',
      () async {
        final code = await aCode();
        for (var cut = 1; cut < 12; cut++) {
          final result = RoutineCode.decode(
            code.substring(0, code.length - cut),
          );
          expect(
            result,
            isA<RoutineCodeFailure>(),
            reason: 'a code missing $cut characters must not decode',
          );
          expect(
            (result as RoutineCodeFailure).problem,
            ShareCodeProblem.damaged,
            reason: 'a code missing $cut characters is damaged, not foreign',
          );
        }
      },
    );

    test('a flipped character never decodes to a different routine', () async {
      final code = await aCode();
      for (var i = '${RoutineCode.version}.'.length; i < code.length; i++) {
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
    Future<SharedRoutine> theirs(
      Future<int> Function(AppDatabase) build,
    ) async {
      final sender = memoryDb();
      addTearDown(sender.close);
      return sender.sharedRoutine(await build(sender));
    }

    test(
      're-creates the routine faithfully, workouts and rep schemes and all',
      () async {
        final shared = await theirs(
          (s) async => (await _routineNamed(s, 'Push / Pull / Legs')).id,
        );

        final id = await db.importSharedRoutine(shared);
        final routine = await db.routineById(id);
        expect(routine.name, 'Push / Pull / Legs');
        expect(routine.colorHex, 'FF6A3D');
        expect(routine.restSeconds, 120);

        final days = await db.workoutsForRoutine(id);
        expect(days.map((w) => w.name), ['Push', 'Pull', 'Legs']);

        final push = await db.itemsForWorkout(days.first.id);
        expect(push.map((v) => v.exercise.name), [
          'Bench Press',
          'Overhead Press',
          'Incline DB Press',
          'Lateral Raise',
          'Triceps Pushdown',
        ]);
        expect(push.first.item.targetSets, 4);
        expect(push.first.item.repsMin, 6);
        expect(push.first.item.repsMax, 8);
      },
    );

    test('a rate the sender never sent is filled in from my unit', () async {
      final shared = await theirs(
        (s) async => (await _routineNamed(s, 'Push / Pull / Legs')).id,
      );
      await db.setWeightUnit('lb');

      final id = await db.importSharedRoutine(shared);
      final days = await db.workoutsForRoutine(id);
      final bench = (await db.itemsForWorkout(
        days.first.id,
      )).firstWhere((v) => v.exercise.name == 'Bench Press').item;

      expect(
        bench.increment,
        closeTo(toKg(5, 'lb'), 1e-6),
        reason: 'a pounds gym steps by 5 lb, not by 5.51',
      );
      expect(bench.deload, closeTo(toKg(10, 'lb'), 1e-6));
    });

    test(
      'a code carries the axis in use and none of the ones it is not',
      () async {
        final shared = await theirs(
          (s) async => (await _routineNamed(s, 'Push / Pull / Legs')).id,
        );

        final id = await db.importSharedRoutine(shared);
        final days = await db.workoutsForRoutine(id);
        final bench = (await db.itemsForWorkout(
          days.first.id,
        )).firstWhere((v) => v.exercise.name == 'Bench Press').item;

        // Where the sender's other axes had got to is not part of the program,
        // so an imported slot starts with nothing kept — its first switch opens
        // on the receiving gym's defaults.
        expect(bench.sparedRates, isNull);
      },
    );

    group('a rate that travelled lands on a tidy number', () {
      /// The sender's routine through the code and back, as a receiving phone
      /// on [unit] would land it: only the string round trip puts a rate
      /// through the format's hundredths-of-a-kilogram quantisation.
      Future<WorkoutItem> landed({
        required double increment,
        required double deload,
        required String unit,
        ProgressionMode mode = ProgressionMode.weight,
      }) async {
        final sender = memoryDb();
        addTearDown(sender.close);
        final exerciseId = await sender.createExercise(
          name: 'Zercher Squat',
          muscles: MuscleMap.single('Legs'),
          equipment: 'Barbell',
          measure: ExerciseMeasure.reps,
          weightType: WeightType.bar,
        );
        final routineId = await sender.createRoutine(
          name: 'Elbow Day',
          color: '3ED598',
          restSeconds: 210,
        );
        await sender.replaceRoutineWorkouts(routineId, [
          (
            id: null,
            name: 'Zerchers',
            items: [
              WorkoutItemsCompanion.insert(
                workoutId: 0,
                exerciseId: exerciseId,
                position: const Value(0),
                targetSets: const Value(3),
                repsMin: const Value(5),
                progression: Value(mode),
                increment: Value(increment),
                deload: Value(deload),
              ),
            ],
          ),
        ]);

        final code = RoutineCode.encode(await sender.sharedRoutine(routineId));
        await db.setWeightUnit(unit);
        final id = await db.importSharedRoutine(
          (RoutineCode.decode(code) as RoutineCodeOk).routine,
        );
        final day = (await db.workoutsForRoutine(id)).single;
        return (await db.itemsForWorkout(day.id)).single.item;
      }

      test('a 2.5 lb step arrives as 2.5 lb, not 2.49', () async {
        final item = await landed(
          increment: toKg(2.5, 'lb'),
          deload: toKg(7.5, 'lb'),
          unit: 'lb',
        );
        expect(
          toDisplayWeight(item.increment, 'lb'),
          closeTo(2.5, 1e-9),
          reason: '1.13 kg off the wire is 2.49 lb until it is rounded',
        );
        expect(toDisplayWeight(item.deload, 'lb'), closeTo(7.5, 1e-9));
      });

      test(
        'a metric rate is rounded in the metric gym that receives it',
        () async {
          final item = await landed(increment: 7.5, deload: 12.5, unit: 'kg');
          expect(item.increment, closeTo(7.5, 1e-9));
          expect(item.deload, closeTo(12.5, 1e-9));
        },
      );

      test('the grid leaves a 1.25 kg step alone', () async {
        final item = await landed(increment: 1.25, deload: 2.5, unit: 'kg');
        expect(
          item.increment,
          closeTo(1.25, 1e-9),
          reason: 'the pair of 1.25s a metric gym steps by',
        );
        expect(item.deload, closeTo(2.5, 1e-9));
      });

      test(
        'it is the same grid a percentage lands on, not a coarser one',
        () async {
          // A rate on the fine grid but not on any coarser one. A separate,
          // coarser import grid used to round these to 1.25 kg and 2.5 lb — a
          // rate the sender never set.
          final metric = await landed(
            increment: 1.125,
            deload: 2.375,
            unit: 'kg',
          );
          expect(metric.increment, closeTo(1.125, 1e-9));
          expect(metric.deload, closeTo(2.375, 1e-9));

          final pounds = await landed(
            increment: toKg(2.25, 'lb'),
            deload: toKg(7.25, 'lb'),
            unit: 'lb',
          );
          expect(toDisplayWeight(pounds.increment, 'lb'), closeTo(2.25, 1e-9));
          expect(toDisplayWeight(pounds.deload, 'lb'), closeTo(7.25, 1e-9));
        },
      );

      test('a rep rate carries no unit and is left alone', () async {
        final item = await landed(
          increment: 3,
          deload: 7,
          unit: 'lb',
          mode: ProgressionMode.reps,
        );
        expect(item.increment, 3);
        expect(item.deload, 7);
      });
    });

    test(
      'the importing phone supplies the weights out of its own history',
      () async {
        final shared = await theirs(
          (s) async => (await _routineNamed(s, 'Push / Pull / Legs')).id,
        );

        // This phone has benched 72.5 kg, whatever the sender presses.
        final bench = (await _exerciseNamed(db, 'Bench Press'))!;
        await db.saveSession(
          routineId: null,
          workoutId: null,
          name: 'Push',
          startedAt: DateTime.now().subtract(const Duration(days: 1)),
          endedAt: DateTime.now().subtract(const Duration(days: 1)),
          durationSeconds: 600,
          totalVolume: 362.5,
          sets: [
            SessionSetsCompanion.insert(
              sessionId: 0,
              exerciseId: Value(bench.id),
              exerciseName: 'Bench Press',
              setNumber: 1,
              weight: const Value(72.5),
              reps: const Value(5),
              done: const Value(true),
            ),
          ],
        );

        final id = await db.importSharedRoutine(shared);
        final days = await db.workoutsForRoutine(id);
        final push = await db.itemsForWorkout(days.first.id);

        final landedBench = push
            .firstWhere((v) => v.exercise.name == 'Bench Press')
            .item;
        expect(
          landedBench.suggestedWeight,
          72.5,
          reason: 'my bench, not theirs',
        );

        final lateral = push
            .firstWhere((v) => v.exercise.name == 'Lateral Raise')
            .item;
        expect(
          lateral.suggestedWeight,
          isNull,
          reason: 'never trained here, so there is nothing to suggest',
        );
      },
    );

    test('reuses the library rather than duplicating it', () async {
      final shared = await theirs(
        (s) async => (await _routineNamed(s, 'Push / Pull / Legs')).id,
      );
      final before = (await db.watchExercises().first).length;

      await db.importSharedRoutine(shared);
      await db.importSharedRoutine(shared);

      expect(
        (await db.watchExercises().first).length,
        before,
        reason: 'the starter library is on both phones already',
      );
      final routines = await db.watchRoutines().first;
      expect(
        routines.where((r) => r.routine.name == 'Push / Pull / Legs'),
        hasLength(2),
        reason: 'two imports, each a routine of its own',
      );
    });

    test('brings a custom exercise the recipient has never seen', () async {
      final shared = await theirs(_seedCustomRoutine);
      expect(await _exerciseNamed(db, 'Zercher Squat'), isNull);

      final arrivals = planExerciseArrivals(
        shared.exercises,
        await db.watchExercises().first,
      );
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
      // There has to be something to take over: the list starts empty, and the
      // first routine to arrive by any route becomes the current one because
      // nothing else is. What this is about is the second one.
      await routineNamed(db);
      final shared = await theirs(_seedCustomRoutine);
      final before = await db.watchActiveRoutineId().first;
      expect(before, isNotNull);

      await db.importSharedRoutine(shared);

      expect(
        await db.watchActiveRoutineId().first,
        before,
        reason: 'importing a routine is not choosing it',
      );
    });

    test('and becomes Today on an install with no routine at all', () async {
      // The other half of the same rule: an import landing in an empty list has
      // nothing to take over, and a list holding exactly one routine beside a
      // Today that says it has nothing to offer is two answers to one question.
      final shared = await theirs(_seedCustomRoutine);
      expect(await db.watchActiveRoutineId().first, isNull);

      final id = await db.importSharedRoutine(shared);

      expect(await db.watchActiveRoutineId().first, id);
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
        muscles: MuscleMap.single('Other'),
        equipment: 'Machine',
        weightType: WeightType.machine,
      );
      return db.exerciseById(id);
    }

    test(
      'is a clash the user is asked about, not a silent overwrite',
      () async {
        final mine = await myZercher();
        final shared = await theirZercher();

        final arrivals = planExerciseArrivals(
          shared.exercises,
          await db.watchExercises().first,
        );
        expect(arrivals.single.isNew, isFalse);
        expect(arrivals.single.clashes, isTrue);
        expect(arrivals.single.existing!.id, mine.id);

        // Default: keep mine.
        final id = await db.importSharedRoutine(shared);
        final kept = await db.exerciseById(mine.id);
        expect(kept.equipment, 'Machine');
        expect(kept.barWeight, isNull);

        final day = (await db.workoutsForRoutine(id)).single;
        expect(
          (await db.itemsForWorkout(day.id)).single.exercise.id,
          mine.id,
          reason: 'the routine points at the exercise I kept',
        );
        expect(
          (await db.watchExercises().first).where(
            (e) => e.name == 'Zercher Squat',
          ),
          hasLength(1),
          reason: 'never a second copy under the same name',
        );
      },
    );

    test(
      'replacing edits in place, so history and other routines survive',
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
      },
    );

    test('a built-in exercise the sender re-measured is a clash too', () async {
      // Their gym's bench sits on a 15 kg bar; mine is on the default.
      final sender = memoryDb();
      addTearDown(sender.close);
      final bench = (await _exerciseNamed(sender, 'Bench Press'))!;
      await sender.setExerciseBarWeight(bench.id, 15);
      final routineId = await sender.createRoutine(
        name: 'Theirs',
        color: 'FF6A3D',
        restSeconds: 90,
      );
      await sender.replaceRoutineWorkouts(routineId, [
        (
          id: null,
          name: 'Day',
          items: [
            WorkoutItemsCompanion.insert(workoutId: 0, exerciseId: bench.id),
          ],
        ),
      ]);
      final shared = await sender.sharedRoutine(routineId);

      final arrivals = planExerciseArrivals(
        shared.exercises,
        await db.watchExercises().first,
      );
      expect(
        arrivals.single.clashes,
        isTrue,
        reason: "their bar weight is a change to my library, so it must ask",
      );

      await db.importSharedRoutine(shared, replace: {0});
      final mine = (await _exerciseNamed(db, 'Bench Press'))!;
      expect(mine.barWeight, 15);
      expect(
        mine.isCustom,
        isFalse,
        reason: 'a starter exercise stays a starter exercise',
      );
    });

    test(
      'my own note on a movement is never overwritten by an import',
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
        expect(
          mine.barWeight,
          15,
          reason: 'Replace did rewrite the definition',
        );
        expect(mine.notes, 'Rack pin 7, bench squeaks');
      },
    );

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
      final shared = await sender.sharedRoutine(
        (await _routineNamed(sender, 'Upper / Lower')).id,
      );

      final arrivals = planExerciseArrivals(
        shared.exercises,
        await db.watchExercises().first,
      );
      expect(arrivals.where((a) => a.clashes), isEmpty);
      expect(arrivals.where((a) => a.isNew), isEmpty);
    });
  });

  group('what arrives reads in the app language', () {
    /// A routine mixing the three cases a name can be in: a starter movement
    /// the recipient has (Bench Press, re-measured so it also clashes), a
    /// starter movement they happen not to have (Pallof Press), and one the
    /// sender invented.
    Future<SharedRoutine> theirMixedRoutine() async {
      final sender = memoryDb();
      addTearDown(sender.close);
      final bench = (await _exerciseNamed(sender, 'Bench Press'))!;
      await sender.setExerciseBarWeight(bench.id, 15);
      final pallof = (await _exerciseNamed(sender, 'Pallof Press'))!;
      final zercher = await sender.createExercise(
        name: 'Zercher Squat',
        muscles: MuscleMap.single('Legs'),
        equipment: 'Barbell',
        measure: ExerciseMeasure.reps,
        weightType: WeightType.bar,
      );
      final routineId = await sender.createRoutine(
        name: 'Elbow Day',
        color: '3ED598',
        restSeconds: 90,
      );
      await sender.replaceRoutineWorkouts(routineId, [
        (
          id: null,
          name: 'Zerchers',
          items: [
            for (final id in [bench.id, pallof.id, zercher])
              WorkoutItemsCompanion.insert(workoutId: 0, exerciseId: id),
          ],
        ),
      ]);
      return sender.sharedRoutine(routineId);
    }

    /// This phone has never had [name] — the case a starter movement added in a
    /// later release than the recipient is running lands in.
    Future<void> forget(String name) =>
        db.customStatement('DELETE FROM exercises WHERE name = ?', [name]);

    testWidgets('the confirmation screen names a starter movement in the app '
        'language, wherever it lists it', (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final code = (await tester.runAsync(() async {
        await forget('Pallof Press');
        return RoutineCode.encode(await theirMixedRoutine());
      }))!;
      final uk = l10nFor(const Locale('uk'));

      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        appUnder(
          container,
          RoutineImportScreen(code: code),
          locale: const Locale('uk'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(seededName(uk, 'bench_press', 'Bench Press')),
        findsWidgets,
        reason: 'the day card, and the clash row asking about the bar',
      );
      expect(find.textContaining('Bench Press'), findsNothing);
      expect(
        find.textContaining(seededName(uk, 'pallof_press', 'Pallof Press')),
        findsWidgets,
        reason: 'the day card, and the list of what will be added',
      );
      expect(find.textContaining('Pallof Press'), findsNothing);
      expect(
        find.textContaining('Zercher Squat'),
        findsWidgets,
        reason: 'a name the sender invented has no translation to find',
      );

      await stop(tester);
    });

    test(
      'a starter movement the recipient lacks arrives as a starter movement',
      () async {
        await forget('Pallof Press');
        final shared = await theirMixedRoutine();

        await db.importSharedRoutine(shared);

        final landed = (await _exerciseNamed(db, 'Pallof Press'))!;
        expect(
          landed.seedKey,
          'pallof_press',
          reason: 'the key is re-derived from the canonical English name',
        );
        expect(
          landed.isCustom,
          isFalse,
          reason: 'it is the movement the app ships, arriving late',
        );

        final zercher = (await _exerciseNamed(db, 'Zercher Squat'))!;
        expect(zercher.seedKey, isNull);
        expect(
          zercher.isCustom,
          isTrue,
          reason: "a movement the sender invented is one of the user's own",
        );
      },
    );

    test('a starter movement is matched on its key before its name', () async {
      // The canonical English name of a starter movement can change between
      // releases; its key cannot. A code written against the old name still
      // has to find the row rather than plant a second copy of the movement.
      await db.customStatement(
        "UPDATE exercises SET name = 'Barbell Bench Press' "
        "WHERE seed_key = 'bench_press'",
      );
      final before = (await db.watchExercises().first).length;
      final shared = await theirMixedRoutine();

      final id = await db.importSharedRoutine(shared);

      expect(
        (await db.watchExercises().first).length,
        before + 1,
        reason: "only the sender's own movement is new here",
      );
      expect(
        (await db.watchExercises().first).where(
          (e) => e.seedKey == 'bench_press',
        ),
        hasLength(1),
      );
      final day = (await db.workoutsForRoutine(id)).single;
      final items = await db.itemsForWorkout(day.id);
      expect(
        items.map((v) => v.exercise.seedKey),
        contains('bench_press'),
        reason: 'the slot points at the row that was already here',
      );
    });

    test('Replace rewrites how a starter movement loads, never what it is '
        'called', () async {
      final shared = SharedRoutine(
        name: 'Theirs',
        colorHex: 'FF6A3D',
        restSeconds: 90,
        scheduleDays: 0,
        exercises: [
          SharedExercise(
            name: 'bench press',
            muscles: MuscleMap.single('Chest'),
            equipment: 'Machine',
            isCustom: true,
            measure: ExerciseMeasure.reps,
            weightType: WeightType.machine,
          ),
        ],
        workouts: [
          SharedWorkout(name: 'Day', items: [SharedItem(exercise: 0)]),
        ],
      );

      await db.importSharedRoutine(shared, replace: {0});

      final mine = (await _exerciseNamed(db, 'Bench Press'))!;
      expect(
        mine.name,
        'Bench Press',
        reason: 'the name is the vocabulary every routine code is written in',
      );
      expect(
        mine.seedKey,
        'bench_press',
        reason: 'so it keeps reading in the app language',
      );
      expect(
        mine.equipment,
        'Machine',
        reason: 'how it loads is the sender\'s to describe',
      );
      expect(
        (await db.watchExercises().first).where(
          (e) => e.seedKey == 'bench_press',
        ),
        hasLength(1),
      );
    });
  });

  group('a link that arrives from outside', () {
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
      expect(route, startsWith('/settings/appearance/import?code='));
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

    test('a whole routine survives being wrapped in one', () async {
      // The inbound path is kept whole even though nothing outbound builds a
      // link any more: a code shared before, or by hand, still has to import.
      final shared = await db.sharedRoutine(await _seedCustomRoutine(db));
      final result = RoutineCode.decode(RoutineCode.link(shared));

      expect(result, isA<RoutineCodeOk>());
      expect((result as RoutineCodeOk).routine.name, 'Elbow Day');
    });

    test('Android is told to hand us every host that can arrive', () {
      // Routing a link is only half of it: with no intent filter for the host,
      // Android never launches the app and `routeForLink` is never asked. That
      // is exactly how routine links came to be inert while theme links worked
      // — the filter named one host and the app routed two.
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      for (final host in [RoutineCode.host, ThemeCode.host]) {
        expect(
          manifest,
          contains('android:scheme="$kShareScheme" android:host="$host"'),
          reason: 'nothing in the manifest catches $kShareScheme://$host/…',
        );
      }
      // And they are catchable from outside the app at all.
      expect(manifest, contains('android.intent.category.BROWSABLE'));
    });
  });

  group('the scanner', () {
    test(
      'a routine QR hands off to the confirmation, and applies nothing',
      () async {
        final code = RoutineCode.encode(
          await db.sharedRoutine(await _seedCustomRoutine(db)),
        );

        expect(readsAsShare(RoutineCode.host, code), isTrue);
        expect(
          importRoute(RoutineCode.host, code),
          startsWith('/routine/import?code='),
          reason: 'the import screen is the only place a code is adopted',
        );
      },
    );

    test('and a scanned link is read the same as a scanned code', () async {
      // The QR the app paints holds the link; a code pasted out of a message is
      // bare. Both arrive at the same screen.
      final shared = await db.sharedRoutine(await _seedCustomRoutine(db));

      expect(readsAsShare(RoutineCode.host, RoutineCode.link(shared)), isTrue);
      expect(
        importRoute(RoutineCode.host, RoutineCode.encode(shared)),
        startsWith('/routine/import?code='),
      );
    });

    test('a code it was not opened for reads as nothing', () async {
      final routine = RoutineCode.encode(
        await db.sharedRoutine(await _seedCustomRoutine(db)),
      );
      final theme = ThemeCode.encode(kDefaultPalette);

      // Held up while importing a routine: a theme code, and the Wi-Fi QR on a
      // café wall. Neither is a routine, so the scanner keeps looking.
      expect(readsAsShare(RoutineCode.host, theme), isFalse);
      expect(
        readsAsShare(RoutineCode.host, 'WIFI:S=Cafe;T=WPA;P=hunter2;;'),
        isFalse,
      );
      expect(readsAsShare(ThemeCode.host, routine), isFalse);
      expect(importRoute('elsewhere', routine), isNull);
    });
  });

  group('the screens', () {
    testWidgets('sharing a routine offers a QR and the code, and nothing else', (
      tester,
    ) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final id = (await tester.runAsync(() => _seedCustomRoutine(db)))!;

      await tester.pumpWidget(
        appUnder(container, RoutineShareScreen(routineId: id)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Elbow Day'), findsWidgets);
      for (final label in ['Show QR', 'Send code']) {
        expect(find.text(label), findsOneWidget);
      }
      // The share sheet sends the code, not a link: a fosslift:// URL is not
      // clickable in a chat app, so it arrived as text to paste anyway. The QR
      // still carries the link, where a camera can act on it.
      expect(find.text('Send link'), findsNothing);
      // The share sheet already offers "copy", and a file saved beside the app
      // is a code you then have to go and find. Both are gone.
      expect(find.text('Copy code'), findsNothing);
      expect(find.text('Save file'), findsNothing);
      // And the symbol lives behind the button, not on the page as well.
      expect(find.byType(QrImageView), findsNothing);

      await stop(tester);
    });

    testWidgets('and the QR holds the link, not the bare code', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final id = (await tester.runAsync(() => _seedCustomRoutine(db)))!;

      await tester.pumpWidget(
        appUnder(container, RoutineShareScreen(routineId: id)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show QR'));
      await tester.pumpAndSettle();

      final qr = tester.widget<ShareQr>(find.byType(ShareQr));
      expect(
        qr.data,
        startsWith(ShareCodec.linkPrefix(RoutineCode.host)),
        reason: 'a phone camera can only act on a symbol holding a link',
      );
      expect(
        RoutineCode.decode(qr.data),
        isA<RoutineCodeOk>(),
        reason: 'and what it holds is the routine',
      );

      await stop(tester);
    });

    testWidgets('Show QR paints a symbol, not an empty dialog', (tester) async {
      // The dialog came up as a dimmed screen and nothing else: ShareQr asked
      // its parent how wide it was through a LayoutBuilder, and AlertDialog
      // sizes its content by an intrinsic-width query a LayoutBuilder cannot
      // answer, so the content measured zero.
      final container = containerFor(db);
      addTearDown(container.dispose);
      final id = (await tester.runAsync(() => _seedCustomRoutine(db)))!;

      await tester.pumpWidget(
        appUnder(container, RoutineShareScreen(routineId: id)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show QR'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final qr = find.byType(QrImageView);
      expect(qr, findsOneWidget, reason: 'the dialog drew no symbol');

      // Big enough for a camera to resolve, and inside the dialog it sits in.
      final drawn = tester.getSize(qr);
      expect(drawn.width, greaterThanOrEqualTo(160));
      expect(drawn.height, greaterThanOrEqualTo(160));
      expect(
        tester.getRect(qr).width,
        lessThanOrEqualTo(tester.getSize(find.byType(AlertDialog)).width),
      );

      await stop(tester);
    });

    testWidgets('an import is previewed and accepted, never applied on arrival', (
      tester,
    ) async {
      final code = (await tester.runAsync(() async {
        final sender = memoryDb();
        addTearDown(sender.close);
        return RoutineCode.encode(
          await sender.sharedRoutine(await _seedCustomRoutine(sender)),
        );
      }))!;

      final container = containerFor(db);
      addTearDown(container.dispose);
      // Everything the import writes is read back through the providers: the
      // write happens inside the widget's own async zone, which only advances
      // as frames are pumped, so awaiting the database directly from here would
      // wait on a transaction that cannot make progress.
      final routines = container.listen(routinesProvider, (_, _) {});
      addTearDown(routines.close);

      await tester.pumpWidget(
        appUnder(container, RoutineImportScreen(code: code)),
      );
      await tester.pumpAndSettle();
      await pumpUntil(tester, () => routines.read().value != null);
      final before = routines.read().value!.length;

      expect(find.text('Elbow Day'), findsWidgets);
      expect(find.textContaining('Zerchers'), findsWidgets);
      expect(
        routines.read().value!.length,
        before,
        reason: 'nothing is written until the user says so',
      );

      await tester.tap(find.text('Add this routine'));
      await pumpUntil(
        tester,
        () => (routines.read().value?.length ?? 0) > before,
        maxFrames: 200,
      );

      final after = routines.read().value!;
      expect(after.length, before + 1);
      expect(after.map((r) => r.routine.name), contains('Elbow Day'));

      await stop(tester);
    });

    testWidgets('a clash is shown with a switch, off by default', (
      tester,
    ) async {
      final code = (await tester.runAsync(() async {
        await db.createExercise(
          name: 'Zercher Squat',
          muscles: MuscleMap.single('Other'),
          equipment: 'Machine',
        );
        final sender = memoryDb();
        addTearDown(sender.close);
        return RoutineCode.encode(
          await sender.sharedRoutine(await _seedCustomRoutine(sender)),
        );
      }))!;

      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        appUnder(container, RoutineImportScreen(code: code)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Zercher Squat'), findsWidgets);
      final switches = find.byType(Switch);
      expect(switches, findsOneWidget);
      expect(
        tester.widget<Switch>(switches).value,
        isFalse,
        reason: 'keeping what I already have is the default',
      );

      final routines = container.listen(routinesProvider, (_, _) {});
      addTearDown(routines.close);
      await pumpUntil(tester, () => routines.read().value != null);
      final before = routines.read().value!.length;

      await tester.tap(find.text('Add this routine'));
      await pumpUntil(
        tester,
        () => (routines.read().value?.length ?? 0) > before,
        maxFrames: 200,
      );

      final library = container.read(exerciseLibraryProvider).value!;
      final mine = library.firstWhere((e) => e.name == 'Zercher Squat');
      expect(
        mine.equipment,
        'Machine',
        reason: 'the switch was left off, so my definition stands',
      );
      expect(library.where((e) => e.name == 'Zercher Squat'), hasLength(1));

      await stop(tester);
    });

    testWidgets('a damaged code explains itself and offers nothing to apply', (
      tester,
    ) async {
      final code = (await tester.runAsync(
        () async => RoutineCode.encode(
          await db.sharedRoutine(await _seedCustomRoutine(db)),
        ),
      ))!;
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        appUnder(
          container,
          RoutineImportScreen(code: code.substring(0, code.length - 6)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('characters missing'), findsOneWidget);
      expect(
        find.text('Add this routine'),
        findsNothing,
        reason: 'there is nothing safe to add',
      );

      await stop(tester);
    });
  });
}
