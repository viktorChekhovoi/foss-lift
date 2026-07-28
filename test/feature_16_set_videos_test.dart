// Integration tests for features/index.html#sec16 — filming a set.
//
// The camera itself is the one part of this a device has to check, and it is
// deliberately the smallest part. Everything that can be got wrong without one
// is here: where a clip lands, what it is named, what happens to the file when
// a workout is abandoned or a set never logged, and the rule the whole storage
// design turns on — that an ordering can strand a file but never a row pointing
// at nothing.
//
// The recorder is faked (see [_FakeRecorder]); the store is real, pointed at a
// temporary directory.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/services/set_video_recorder.dart';
import 'package:foss_lift/screens/exercise_clips_screen.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/util/clip_label.dart';
import 'package:path/path.dart' as p;

import 'support/harness.dart';
import 'support/seeded.dart';

/// A recorder that writes a small file and hands back its path, so everything
/// downstream of "the camera produced a file" is exercised for real.
class _FakeRecorder implements SetVideoRecorder {
  _FakeRecorder(this.scratch);
  final Directory scratch;

  int opened = 0;
  int closed = 0;
  int? openedAtHeight;
  bool recording = false;

  @override
  Future<void> open(int height) async {
    opened++;
    openedAtHeight = height;
  }

  @override
  Widget preview() => const SizedBox.shrink();

  @override
  Future<void> start() async => recording = true;

  @override
  Future<String?> stop() async {
    if (!recording) return null;
    recording = false;
    final file = File(p.join(scratch.path, 'take${opened}_$closed.mp4'));
    await file.writeAsBytes(List.filled(2048, 7));
    return file.path;
  }

  @override
  Future<void> close() async => closed++;
}

void main() {
  late AppDatabase db;
  late Directory root;
  late Directory scratch;
  late SetVideoStore store;
  ProviderContainer? container;

  setUp(() async {
    db = memoryDb();
    root = await Directory.systemTemp.createTemp('fosslift_clips');
    scratch = await Directory.systemTemp.createTemp('fosslift_camera');
    store = SetVideoStore(baseDirectory: () async => root);
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
    if (await scratch.exists()) await scratch.delete(recursive: true);
  });

  ProviderContainer withStore({SetVideoRecorder? recorder}) => containerFor(
        db,
        overrides: [
          setVideoStoreProvider.overrideWithValue(store),
          if (recorder != null)
            setVideoRecorderProvider.overrideWithValue(recorder),
        ],
      );

  /// A file in the clip folder, as if one had been recorded.
  Future<String> plantClip({int bytes = 1024, DateTime? modified}) async {
    await store.directory();
    final relative = store.newRelativePath();
    final file = await store.fileFor(relative);
    await file.writeAsBytes(List.filled(bytes, 1));
    if (modified != null) await file.setLastModified(modified);
    return relative;
  }

  group('where a clip goes and what it is called', () {
    test('every path is relative, and inside the clip folder', () async {
      final relative = store.newRelativePath();

      expect(p.isRelative(relative), isTrue,
          reason: 'an absolute path dangles on iOS after a reinstall');
      expect(p.split(relative).first, SetVideoStore.folder);
      expect(p.extension(relative), '.mp4');
    });

    test('two clips made in the same instant do not collide', () async {
      final paths = {for (var i = 0; i < 50; i++) store.newRelativePath()};
      expect(paths, hasLength(50));
    });

    test('the name says nothing about what was trained', () async {
      // A timestamp collides and a name leaks; the id is neither.
      final relative = store.newRelativePath();
      expect(relative.toLowerCase(), isNot(contains('bench')));
      expect(relative.toLowerCase(), isNot(contains('squat')));
    });

    test('a recorded file is adopted into the folder and the original goes',
        () async {
      final recorded = File(p.join(scratch.path, 'camera_output.mp4'));
      await recorded.writeAsBytes(List.filled(4096, 3));

      final relative = await store.adopt(recorded.path);

      expect(await (await store.fileFor(relative)).exists(), isTrue);
      expect(await recorded.exists(), isFalse,
          reason: 'the camera\'s copy is not left lying about');
      expect(p.split(relative).first, SetVideoStore.folder);
    });

    test('a relative path resolves under whatever the base is now', () async {
      // The whole reason paths are relative: the container moves, the clip
      // does not.
      final relative = await plantClip();
      final moved = SetVideoStore(baseDirectory: () async => root);
      expect(await moved.exists(relative), isTrue);
    });
  });

  group('deleting', () {
    test('deleting a clip that is already gone is not an error', () async {
      final relative = await plantClip();
      await store.delete(relative);
      await store.delete(relative);
      expect(await store.exists(relative), isFalse);
    });

    test('bytesUsed counts what is actually on disk', () async {
      expect(await store.bytesUsed(), 0);
      await plantClip(bytes: 1000);
      await plantClip(bytes: 2000);
      expect(await store.bytesUsed(), 3000);
    });

    test('a folder nobody has filmed into reports nothing rather than throwing',
        () async {
      expect(await store.bytesUsed(), 0);
      expect(await store.sweepOrphans(const {}), 0);
    });
  });

  group('the orphan sweep', () {
    test('removes a file no set points at', () async {
      final orphan =
          await plantClip(modified: DateTime.now().subtract(const Duration(days: 2)));

      expect(await store.sweepOrphans(const {}), 1);
      expect(await store.exists(orphan), isFalse);
    });

    test('leaves a file a set does point at', () async {
      final kept =
          await plantClip(modified: DateTime.now().subtract(const Duration(days: 2)));

      expect(await store.sweepOrphans({kept}), 0);
      expect(await store.exists(kept), isTrue);
    });

    test('leaves a clip filmed moments ago, which has no row yet by design',
        () async {
      // The live session is in memory until Finish, so a fresh clip is
      // *supposed* to be unreferenced. Without the grace period the sweep would
      // delete the set being filmed right now.
      final fresh = await plantClip();

      expect(await store.sweepOrphans(const {}), 0);
      expect(await store.exists(fresh), isTrue);
    });

    test('a zero grace takes everything unreferenced — the reclaim path',
        () async {
      final fresh = await plantClip();
      expect(await store.sweepOrphans(const {}, grace: Duration.zero), 1);
      expect(await store.exists(fresh), isFalse);
    });
  });

  group('a clip on a live set', () {
    /// Starts a session on the seeded Push day and returns its controller.
    Future<ActiveWorkoutController> startPush(ProviderContainer c) async {
      final workoutId = await workoutIdNamed(db, 'Push');
      final controller = c.read(activeWorkoutProvider.notifier);
      await controller.start(workoutId: workoutId, name: 'Push');
      return controller;
    }

    test('attaching hangs the path on that set and no other', () async {
      container = withStore();
      final controller = await startPush(container!);
      final relative = await plantClip();

      await controller.attachVideo(0, 1, relative);

      final session = container!.read(activeWorkoutProvider)!;
      expect(session.exercises[0].sets[1].videoPath, relative);
      expect(session.exercises[0].sets[0].videoPath, isNull);
    });

    test('re-filming replaces the take, and deletes the one it replaced',
        () async {
      container = withStore();
      final controller = await startPush(container!);
      final first = await plantClip();
      final second = await plantClip();

      await controller.attachVideo(0, 0, first);
      await controller.attachVideo(0, 0, second);

      expect(container!.read(activeWorkoutProvider)!.exercises[0].sets[0]
          .videoPath, second);
      expect(await store.exists(first), isFalse,
          reason: 'the replaced take goes now, not in a day');
      expect(await store.exists(second), isTrue);
    });

    test('deleting a clip leaves the set exactly as it was', () async {
      container = withStore();
      final controller = await startPush(container!);
      final relative = await plantClip();
      await controller.attachVideo(0, 0, relative);
      controller.cycleSet(0, 0);
      final loggedBefore =
          container!.read(activeWorkoutProvider)!.exercises[0].sets[0].logged;

      await controller.removeVideo(0, 0);

      final set = container!.read(activeWorkoutProvider)!.exercises[0].sets[0];
      expect(set.videoPath, isNull);
      expect(set.logged, loggedBefore,
          reason: 'a bad take is not a set that did not happen');
      expect(await store.exists(relative), isFalse);
    });

    test('nothing is written to the database before Finish', () async {
      container = withStore();
      final controller = await startPush(container!);
      await controller.attachVideo(0, 0, await plantClip());

      expect(await db.allVideoPaths(), isEmpty,
          reason: 'the live workout stays in memory, clips included');
    });
  });

  group('what happens to the files when the session ends', () {
    Future<ActiveWorkoutController> startPush(ProviderContainer c) async {
      final workoutId = await workoutIdNamed(db, 'Push');
      final controller = c.read(activeWorkoutProvider.notifier);
      await controller.start(workoutId: workoutId, name: 'Push');
      return controller;
    }

    test('Finish writes the path alongside the set it belongs to', () async {
      container = withStore();
      final controller = await startPush(container!);
      final relative = await plantClip();
      await controller.attachVideo(0, 0, relative);
      controller.cycleSet(0, 0);

      final sessionId = await controller.finish();

      final sets = await db.setsForSession(sessionId!);
      expect(sets.first.videoPath, relative);
      expect(await store.exists(relative), isTrue);
      expect(await db.allVideoPaths(), {relative});
    });

    test('a clip on a set that was never logged does not survive Finish',
        () async {
      container = withStore();
      final controller = await startPush(container!);
      final logged = await plantClip();
      final abandoned = await plantClip();
      await controller.attachVideo(0, 0, logged);
      await controller.attachVideo(0, 1, abandoned);
      // Only the first set is logged, so only it is saved.
      controller.cycleSet(0, 0);

      await controller.finish();

      expect(await store.exists(logged), isTrue);
      expect(await store.exists(abandoned), isFalse,
          reason: 'nothing would ever have pointed at it');
    });

    test('abandoning a workout takes its clips with it', () async {
      container = withStore();
      final controller = await startPush(container!);
      final one = await plantClip();
      final two = await plantClip();
      await controller.attachVideo(0, 0, one);
      await controller.attachVideo(1, 0, two);

      await controller.discard();

      expect(await store.exists(one), isFalse);
      expect(await store.exists(two), isFalse);
      expect(await store.bytesUsed(), 0,
          reason: 'a binned session leaves no footage behind');
    });

    test('a saved clip is never left dangling — file and row agree', () async {
      container = withStore();
      final controller = await startPush(container!);
      final relative = await plantClip();
      await controller.attachVideo(0, 0, relative);
      controller.cycleSet(0, 0);
      await controller.finish();

      // The invariant the whole ordering exists for.
      for (final path in await db.allVideoPaths()) {
        expect(await store.exists(path), isTrue,
            reason: 'a row pointing at a file that is gone is the one failure '
                'this design refuses');
      }
    });
  });

  group('clearing every clip', () {
    test('forgets the rows and, with a zero grace, the files', () async {
      container = withStore();
      final workoutId = await workoutIdNamed(db, 'Push');
      final controller = container!.read(activeWorkoutProvider.notifier);
      await controller.start(workoutId: workoutId, name: 'Push');
      final relative = await plantClip();
      await controller.attachVideo(0, 0, relative);
      controller.cycleSet(0, 0);
      final sessionId = await controller.finish();

      await db.clearAllSetVideos();
      await store.sweepOrphans(const {}, grace: Duration.zero);

      expect(await db.allVideoPaths(), isEmpty);
      expect(await store.exists(relative), isFalse);
      final sets = await db.setsForSession(sessionId!);
      expect(sets, isNotEmpty, reason: 'the sets stay; only the clips go');
      expect(sets.first.videoPath, isNull);
    });
  });

  group('the recorder, faked', () {
    test('is opened at the chosen height, without audio, and closed after',
        () async {
      // The audio half is a property of the real implementation and cannot be
      // asserted through the interface — the interface has no way to ask for
      // audio at all, which is the point.
      final recorder = _FakeRecorder(scratch);
      await recorder.open(480);
      await recorder.start();
      final produced = await recorder.stop();
      await recorder.close();

      expect(recorder.openedAtHeight, 480);
      expect(produced, isNotNull);
      expect(recorder.closed, 1, reason: 'the camera is never left open');
    });

    test('stopping without starting produces nothing', () async {
      final recorder = _FakeRecorder(scratch);
      await recorder.open(720);
      expect(await recorder.stop(), isNull);
    });
  });

  group('the caps on one clip', () {
    test('a fresh install films at 720p with a one-minute stop', () async {
      final setting = await db.watchVideoSetting().first;
      expect(setting.height, 720);
      expect(setting.maxSeconds, 60);
    });

    test('both settings round-trip', () async {
      await db.setVideoHeight(480);
      await db.setVideoMaxSeconds(180);
      final setting = await db.watchVideoSetting().first;
      expect(setting.height, 480);
      expect(setting.maxSeconds, 180);
    });

    test('1080p is not on offer', () {
      expect(kVideoHeights, isNot(contains(1080)),
          reason: 'two and a half times the bytes for the same judgement');
      expect(kVideoHeights, [480, 720]);
    });

    test('a stored value the app does not offer falls back to the default', () {
      expect(resolveVideoHeight(1080), kDefaultVideoHeight);
      expect(resolveVideoHeight(null), kDefaultVideoHeight);
      expect(resolveVideoMaxSeconds(99999), kDefaultVideoSeconds);
      expect(resolveVideoMaxSeconds(null), kDefaultVideoSeconds,
          reason: 'never "no limit at all"');
    });

    test('the recording clock stops itself at the cap', () {
      expect(recordingExpired((elapsed: 59, max: 60)), isFalse);
      expect(recordingExpired((elapsed: 60, max: 60)), isTrue);
      expect(recordingExpired((elapsed: 61, max: 60)), isTrue,
          reason: 'a tick that overshoots still stops');
    });

    test('the countdown appears for the last five seconds and not before', () {
      expect(recordingCountingDown((elapsed: 54, max: 60)), isFalse);
      expect(recordingCountingDown((elapsed: 55, max: 60)), isTrue);
      expect(recordingRemaining((elapsed: 55, max: 60)), 5);
      expect(recordingRemaining((elapsed: 70, max: 60)), 0,
          reason: 'never a negative countdown');
    });
  });

  group('finding a clip again', () {
    test('the per-exercise reel lists this movement, newest first', () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      final older = await plantClip();
      final newer = await plantClip();

      for (final (index, path) in [older, newer].indexed) {
        await db.saveSession(
          routineId: null,
          workoutId: null,
          name: 'Push',
          startedAt: DateTime(2026, 3, 1 + index),
          endedAt: DateTime(2026, 3, 1 + index, 1),
          durationSeconds: 600,
          totalVolume: 100,
          sets: [
            SessionSetsCompanion.insert(
              sessionId: 0,
              exerciseName: 'Bench Press',
              setNumber: 1,
              exerciseId: Value(bench.id),
              done: const Value(true),
              videoPath: Value(path),
            ),
          ],
        );
      }

      final reel = await db.watchExerciseClips(bench.id).first;
      expect([for (final s in reel) s.videoPath], [newer, older]);
      expect(reel.first.date, DateTime(2026, 3, 2));
    });

    test('sets nobody filmed are not in the reel', () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      await db.saveSession(
        routineId: null,
        workoutId: null,
        name: 'Push',
        startedAt: DateTime(2026, 3, 1),
        endedAt: DateTime(2026, 3, 1, 1),
        durationSeconds: 600,
        totalVolume: 100,
        sets: [
          SessionSetsCompanion.insert(
            sessionId: 0,
            exerciseName: 'Bench Press',
            setNumber: 1,
            exerciseId: Value(bench.id),
            done: const Value(true),
          ),
        ],
      );

      expect(await db.watchExerciseClips(bench.id).first, isEmpty);
      expect(await db.watchExerciseSetHistory(bench.id).first, hasLength(1),
          reason: 'the set is still history; it just has no clip');
    });
  });

  group('what a clip says it is', () {
    ExerciseSetEntry entry({
      double weightKg = 100,
      int reps = 5,
      int? seconds,
      int setNumber = 3,
    }) =>
        ExerciseSetEntry(
          setId: 1,
          sessionId: 1,
          date: DateTime(2026, 3, 12),
          sessionName: 'Push',
          setNumber: setNumber,
          weightKg: weightKg,
          reps: reps,
          seconds: seconds,
          done: true,
          videoPath: 'set_videos/x.mp4',
        );

    test('the date, the set, and what was done', () {
      expect(clipLabel(entry(), 'kg'), '12 Mar · set 3 · 100 kg × 5');
    });

    test('it follows the display unit', () {
      expect(clipLabel(entry(weightKg: 100), 'lb'), contains('lb'));
      expect(clipLabel(entry(weightKg: 100), 'lb'), isNot(contains('kg')));
    });

    test('a held set reads its duration, not a rep count', () {
      expect(clipLabel(entry(weightKg: 0, reps: 0, seconds: 45), 'kg'),
          '12 Mar · set 3 · 45s');
    });

    test('an unloaded set does not claim to have been 0 kg', () {
      expect(clipLabel(entry(weightKg: 0, reps: 12), 'kg'),
          '12 Mar · set 3 · 12 reps');
    });

    test('a half-kilo weight keeps its decimal, a whole one loses it', () {
      expect(clipLabel(entry(weightKg: 102.5), 'kg'), contains('102.5 kg'));
      expect(clipLabel(entry(weightKg: 100), 'kg'), contains('100 kg'));
    });

    test('the recap and the reel say the same thing about the same set', () {
      final e = entry();
      expect(
        clipLabelOf(
          date: e.date,
          setNumber: e.setNumber,
          weightKg: e.weightKg,
          reps: e.reps,
          seconds: e.seconds,
          unit: 'kg',
        ),
        clipLabel(e, 'kg'),
      );
    });
  });

  group('playing one back', () {
    test('slow motion goes down, never up', () {
      expect(kPlaybackSpeeds, [1.0, 0.5, 0.25]);
      expect(kPlaybackSpeeds.every((s) => s <= 1.0), isTrue,
          reason: 'this is for inspecting a rep, not skipping one');
    });

    test('the speed control cycles and wraps', () {
      expect(nextPlaybackSpeed(1.0), 0.5);
      expect(nextPlaybackSpeed(0.5), 0.25);
      expect(nextPlaybackSpeed(0.25), 1.0);
    });

    test('a speed from nowhere resolves to full rather than sticking', () {
      expect(nextPlaybackSpeed(2.0), 1.0);
    });

    test('a speed reads the way somebody would say it', () {
      expect(fmtPlaybackSpeed(1.0), '1×');
      expect(fmtPlaybackSpeed(0.5), '0.5×');
      expect(fmtPlaybackSpeed(0.25), '0.25×');
    });
  });

  group('the reel on screen', () {
    testWidgets('lists every clip of the movement, newest first',
        (tester) async {
      final bench = await tester.runAsync(
              () async => exerciseNamed(db, 'Bench Press')) as Exercise;
      await tester.runAsync(() async {
        for (final (index, weight) in [80.0, 90.0].indexed) {
          await db.saveSession(
            routineId: null,
            workoutId: null,
            name: 'Push',
            startedAt: DateTime(2026, 3, 1 + index),
            endedAt: DateTime(2026, 3, 1 + index, 1),
            durationSeconds: 600,
            totalVolume: 100,
            sets: [
              SessionSetsCompanion.insert(
                sessionId: 0,
                exerciseName: 'Bench Press',
                setNumber: 1,
                exerciseId: Value(bench.id),
                weight: Value(weight),
                reps: const Value(5),
                done: const Value(true),
                videoPath: Value(await plantClip()),
              ),
            ],
          );
        }
      });

      container = withStore();
      await tester.pumpWidget(
          routedAppUnder(container!, ExerciseClipsScreen(exerciseId: bench.id)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('2 Mar · set 1 · 90 kg × 5'), findsOneWidget);
      expect(find.text('1 Mar · set 1 · 80 kg × 5'), findsOneWidget);
      // Newest first: the 2 Mar row is above the 1 Mar one.
      expect(
        tester.getTopLeft(find.text('2 Mar · set 1 · 90 kg × 5')).dy,
        lessThan(tester.getTopLeft(find.text('1 Mar · set 1 · 80 kg × 5')).dy),
      );

      await stop(tester);
    });

    testWidgets('a movement nobody has filmed says so plainly', (tester) async {
      final bench = await tester.runAsync(
              () async => exerciseNamed(db, 'Bench Press')) as Exercise;
      container = withStore();
      await tester.pumpWidget(
          routedAppUnder(container!, ExerciseClipsScreen(exerciseId: bench.id)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Nothing filmed yet.'), findsOneWidget);

      await stop(tester);
    });
  });

  group('a size, said out loud', () {
    test('reads in the unit a person would use', () {
      expect(fmtBytes(512), '512 B');
      expect(fmtBytes(2048), '2.0 kB');
      expect(fmtBytes(15 * 1024 * 1024), '15 MB');
      expect(fmtBytes(3 * 1024 * 1024 * 1024), '3.0 GB');
    });
  });
}
