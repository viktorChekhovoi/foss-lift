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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

/// A real, minimal JPEG. The fake decoder writes this rather than random bytes
/// so a still that reaches the screen is something an `Image` can actually
/// decode — a row that shows a broken image is not a row that shows a frame.
final Uint8List _onePixelJpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRof'
  'Hh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwh'
  'MjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAAR'
  'CAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAA'
  'AgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkK'
  'FhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWG'
  'h4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl'
  '5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREA'
  'AgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYk'
  'NOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOE'
  'hYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk'
  '5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD3+iiigD//2Q==',
);

/// A frame decoder that writes a real file and counts what it was asked to
/// read.
///
/// Counting is the point: "decoded once and kept beside the clip" is a claim
/// about how often the expensive call happens, and a decoder that only reported
/// success could not tell a cached still from a freshly decoded one.
class _FakeDecoder {
  _FakeDecoder({this.refuses = const {}, this.throwsOn = const {}});

  /// Clip file names this decoder cannot read at all, and ones that make it
  /// blow up rather than politely decline.
  final Set<String> refuses;
  final Set<String> throwsOn;

  /// Every clip it was handed, in order.
  final List<String> decoded = [];

  Future<bool> call({
    required String srcFile,
    required String destFile,
    required int width,
    required int height,
  }) async {
    decoded.add(p.basename(srcFile));
    if (throwsOn.contains(p.basename(srcFile))) {
      throw const FileSystemException('this container is not readable');
    }
    if (refuses.contains(p.basename(srcFile))) return false;
    await File(destFile).writeAsBytes(_onePixelJpeg);
    return true;
  }

  /// How many times [relative]'s clip was decoded.
  int timesOn(String relative) =>
      decoded.where((name) => name == p.basename(relative)).length;
}

/// What the reel writes on the row for a set of [reps] at [weightKg] filmed on
/// [day] March 2026 — asked of the same label the screen builds its rows from,
/// so the assertion says "the row reads what a clip reads" rather than freezing
/// one language's word order into the test.
String marchRow(int day, double weightKg, {int setNumber = 1, int reps = 5}) =>
    clipLabelOf(
      l10nFor(),
      date: DateTime(2026, 3, day),
      setNumber: setNumber,
      weightKg: weightKg,
      reps: reps,
      unit: 'kg',
    );

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

  /// A cached frame sitting beside [clipRelative], as if the reel had already
  /// been looked at once.
  Future<String> plantStill(String clipRelative, {DateTime? modified}) async {
    await store.directory();
    final relative = store.stillPathFor(clipRelative);
    final file = await store.fileFor(relative);
    await file.writeAsBytes(_onePixelJpeg);
    if (modified != null) await file.setLastModified(modified);
    return relative;
  }

  /// The thumbnailer under test, on the real store with a faked decoder.
  SetVideoThumbnails thumbnails(_FakeDecoder decoder) =>
      SetVideoThumbnails(store, decode: decoder.call);

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

    test('a still sits beside its clip, same folder and same id', () async {
      // Same id, different extension: that is the whole lookup. Nothing else
      // has to be stored to find a clip's frame again.
      expect(store.stillPathFor(p.join(SetVideoStore.folder, 'abc.mp4')),
          p.join(SetVideoStore.folder, 'abc.jpg'));
      expect(SetVideoStore.stillExtension, '.jpg');

      final clip = store.newRelativePath();
      final still = store.stillPathFor(clip);
      expect(p.isRelative(still), isTrue,
          reason: 'an absolute path dangles on iOS after a reinstall');
      expect(p.split(still).first, SetVideoStore.folder);
      expect(p.basenameWithoutExtension(still),
          p.basenameWithoutExtension(clip));
    });

    test('deleting a clip takes its cached frame with it', () async {
      // Nothing points at a still, so if delete left it behind it would only
      // ever be collected by chance.
      final clip = await plantClip();
      final still = await plantStill(clip);

      await store.delete(clip);

      expect(await store.exists(clip), isFalse);
      expect(await store.exists(still), isFalse);
    });

    test('deleting a clip that never had a frame is still quiet', () async {
      final clip = await plantClip();
      await store.delete(clip);
      expect(await store.exists(store.stillPathFor(clip)), isFalse);
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

    test('a still whose clip is kept is kept too, though no row names it',
        () async {
      // The trap this rule exists for: nothing in the database ever points at
      // a still, so a sweep that asked the same question of every file would
      // bin every cached frame on the first launch after one existed.
      final old = DateTime.now().subtract(const Duration(days: 2));
      final kept = await plantClip(modified: old);
      final still = await plantStill(kept, modified: old);

      expect(await store.sweepOrphans({kept}), 0);
      expect(await store.exists(still), isTrue);
    });

    test('a swept clip takes its still with it', () async {
      final old = DateTime.now().subtract(const Duration(days: 2));
      final orphan = await plantClip(modified: old);
      final still = await plantStill(orphan, modified: old);

      expect(await store.sweepOrphans(const {}), 1,
          reason: 'the count is clips removed, not files removed');
      expect(await store.exists(orphan), isFalse);
      expect(await store.exists(still), isFalse);
    });

    test('a still whose clip has already gone is collected on the second pass',
        () async {
      // A clip removed by hand, or by a sweep that died halfway, leaves a
      // frame of something that cannot be played.
      final old = DateTime.now().subtract(const Duration(days: 2));
      final clip = await plantClip(modified: old);
      final still = await plantStill(clip, modified: old);
      await (await store.fileFor(clip)).delete();

      expect(await store.sweepOrphans(const {}), 0,
          reason: 'no clip went, so nothing is counted');
      expect(await store.exists(still), isFalse);
    });

    test('the still of a clip filmed moments ago survives with its clip',
        () async {
      final fresh = await plantClip();
      final still = await plantStill(fresh);

      expect(await store.sweepOrphans(const {}), 0);
      expect(await store.exists(fresh), isTrue);
      expect(await store.exists(still), isTrue);
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

  group('the frame a row shows', () {
    test('a clip with no frame yet gets one decoded and kept beside it',
        () async {
      final decoder = _FakeDecoder();
      final clip = await plantClip();

      final still = await thumbnails(decoder).stillFor(clip);

      expect(still, isNotNull);
      expect(await still!.exists(), isTrue);
      expect(still.path, (await store.fileFor(store.stillPathFor(clip))).path,
          reason: 'the frame lives beside the clip, not in a cache directory');
      expect(decoder.timesOn(clip), 1);
    });

    test('a frame already on disk is handed back without decoding', () async {
      // The clip is listed on every visit to the reel; decoding on every one is
      // the naive version, and it gets slower the more you film.
      final decoder = _FakeDecoder();
      final clip = await plantClip();
      final planted = await plantStill(clip);

      final still = await thumbnails(decoder).stillFor(clip);

      expect(still, isNotNull);
      expect(still!.path, (await store.fileFor(planted)).path);
      expect(decoder.decoded, isEmpty);
    });

    test('a clip is never decoded twice in one process', () async {
      final decoder = _FakeDecoder();
      final clip = await plantClip();
      final subject = thumbnails(decoder);

      await subject.stillFor(clip);
      // Even with the cached file taken away underneath it, the decode is not
      // run again — this process has already answered the question once.
      await (await store.fileFor(store.stillPathFor(clip))).delete();
      await subject.stillFor(clip);

      expect(decoder.timesOn(clip), 1);
    });

    test('two rows asking at once share the one decode', () async {
      // The reel builds its rows together, so the first paint asks for every
      // frame at the same moment.
      final decoder = _FakeDecoder();
      final clip = await plantClip();
      final subject = thumbnails(decoder);

      final both =
          await Future.wait<File?>(
              [subject.stillFor(clip), subject.stillFor(clip)]);

      expect(decoder.timesOn(clip), 1);
      expect(both.first?.path, both.last?.path);
      expect(both.first, isNotNull);
    });

    test('a clip whose file has gone is not decoded at all', () async {
      final decoder = _FakeDecoder();
      final clip = await plantClip();
      await (await store.fileFor(clip)).delete();

      expect(await thumbnails(decoder).stillFor(clip), isNull);
      expect(decoder.decoded, isEmpty,
          reason: 'nothing to read; asking the decoder is a wasted call');
      expect(await store.exists(store.stillPathFor(clip)), isFalse);
    });

    test('a decoder that will not read the clip leaves nothing behind',
        () async {
      final clip = await plantClip();
      final decoder = _FakeDecoder(refuses: {p.basename(clip)});

      expect(await thumbnails(decoder).stillFor(clip), isNull);
      expect(await store.exists(store.stillPathFor(clip)), isFalse,
          reason: 'a half-written frame would be served forever after');
    });

    test('a decoder that throws is not the reel\'s problem', () async {
      final clip = await plantClip();
      final decoder = _FakeDecoder(throwsOn: {p.basename(clip)});

      expect(await thumbnails(decoder).stillFor(clip), isNull);
    });

    test('a clip that failed to decode is not retried on every build',
        () async {
      // The expensive call is the decode, and a clip the decoder cannot read
      // stays unreadable — retrying it per frame is how a broken clip costs
      // more than a working one.
      final clip = await plantClip();
      final decoder = _FakeDecoder(refuses: {p.basename(clip)});
      final subject = thumbnails(decoder);

      expect(await subject.stillFor(clip), isNull);
      expect(await subject.stillFor(clip), isNull);

      expect(decoder.timesOn(clip), 1);
    });

    test('the provider hangs off the same store the clips are in', () async {
      container = withStore();
      final subject = container!.read(setVideoThumbnailsProvider);
      final clip = await plantClip();

      // No decoder is injected here, so the only thing it can answer without
      // one is a frame that is already on disk.
      final planted = await plantStill(clip);
      expect((await subject.stillFor(clip))?.path,
          (await store.fileFor(planted)).path);
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

    // The words come from the catalogue, so the assertions ask it for them
    // rather than re-typing the English: what a label has to get right is which
    // of the four messages it picks and what it fills in — the date the way the
    // language writes it, the set, the load in the display unit, the effort.
    final l10n = l10nFor();
    final date = DateTime(2026, 3, 12);

    test('the date, the set, and what was done', () {
      expect(clipLabel(l10n, entry(), 'kg'),
          l10n.clipLabelLoadedReps(
              date, 3, l10n.unitWeightShort('100', l10n.unitKgSuffix), 5));
    });

    test('it follows the display unit', () {
      final label = clipLabel(l10n, entry(weightKg: 100), 'lb');
      expect(label, contains(l10n.unitLbSuffix));
      expect(label, isNot(contains(l10n.unitKgSuffix)));
    });

    test('a held set reads its duration, not a rep count', () {
      expect(clipLabel(l10n, entry(weightKg: 0, reps: 0, seconds: 45), 'kg'),
          l10n.clipLabelHold(date, 3, l10n.unitSecondsShort('45')));
    });

    test('an unloaded set does not claim to have been 0 kg', () {
      expect(clipLabel(l10n, entry(weightKg: 0, reps: 12), 'kg'),
          l10n.clipLabelReps(date, 3, 12));
    });

    test('one rep is one rep, not "1 reps"', () {
      // The rep count is a plural in the catalogue, so the label agrees with
      // itself at a count of one. It reads "1 rep" in English; a language with
      // more plural forms than two picks its own.
      expect(clipLabel(l10n, entry(weightKg: 0, reps: 1), 'kg'),
          l10n.clipLabelReps(date, 3, 1));
      expect(clipLabel(l10n, entry(weightKg: 0, reps: 1), 'kg'),
          isNot(clipLabel(l10n, entry(weightKg: 0, reps: 2), 'kg')));
    });

    test('a half-kilo weight keeps its decimal, a whole one loses it', () {
      final kg = l10n.unitKgSuffix;
      expect(clipLabel(l10n, entry(weightKg: 102.5), 'kg'),
          contains(l10n.unitWeightShort('102.5', kg)));
      expect(clipLabel(l10n, entry(weightKg: 100), 'kg'),
          contains(l10n.unitWeightShort('100', kg)));
    });

    test('the recap and the reel say the same thing about the same set', () {
      final e = entry();
      expect(
        clipLabelOf(
          l10n,
          date: e.date,
          setNumber: e.setNumber,
          weightKg: e.weightKg,
          reps: e.reps,
          seconds: e.seconds,
          unit: 'kg',
        ),
        clipLabel(l10n, e, 'kg'),
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

      expect(find.text(marchRow(2, 90)), findsOneWidget);
      expect(find.text(marchRow(1, 80)), findsOneWidget);
      // Newest first: the 2 Mar row is above the 1 Mar one.
      expect(
        tester.getTopLeft(find.text(marchRow(2, 90))).dy,
        lessThan(tester.getTopLeft(find.text(marchRow(1, 80))).dy),
      );

      await stop(tester);
    });

    /// One filmed set of [exercise], on 1 March, at 80 kg × 5.
    Future<String> filmedSet(WidgetTester tester, Exercise exercise) async {
      late String clip;
      await tester.runAsync(() async {
        clip = await plantClip();
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
              exerciseId: Value(exercise.id),
              weight: const Value(80),
              reps: const Value(5),
              done: const Value(true),
              videoPath: Value(clip),
            ),
          ],
        );
      });
      return clip;
    }

    ProviderContainer withThumbnails(_FakeDecoder decoder) => containerFor(
          db,
          overrides: [
            setVideoStoreProvider.overrideWithValue(store),
            setVideoThumbnailsProvider
                .overrideWithValue(SetVideoThumbnails(store, decode: decoder.call)),
          ],
        );

    testWidgets('a row shows a frame from its own clip', (tester) async {
      // Six squat sets should look like six squats, not six identical play
      // symbols — scanning for the session you meant is what the reel is for.
      final bench = await tester.runAsync(
              () async => exerciseNamed(db, 'Bench Press')) as Exercise;
      await filmedSet(tester, bench);

      final decoder = _FakeDecoder();
      container = withThumbnails(decoder);
      await tester.pumpWidget(
          routedAppUnder(container!, ExerciseClipsScreen(exerciseId: bench.id)));
      await pumpThroughDatabase(tester);

      expect(find.text(marchRow(1, 80)), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing,
          reason: 'the frame replaces the symbol; it does not sit beside it');

      await stop(tester);
    });

    testWidgets('a row whose frame will not decode still reads and still plays',
        (tester) async {
      // A decoder that cannot read one clip is not a reason to hide the clip.
      final bench = await tester.runAsync(
              () async => exerciseNamed(db, 'Bench Press')) as Exercise;
      final clip = await filmedSet(tester, bench);

      final decoder = _FakeDecoder(refuses: {p.basename(clip)});
      container = withThumbnails(decoder);
      await tester.pumpWidget(routedAppUnder(
        container!,
        ExerciseClipsScreen(exerciseId: bench.id),
        alsoRoutes: ['clip'],
      ));
      await pumpThroughDatabase(tester);

      expect(find.text(marchRow(1, 80)), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      await tester.tap(find.text(marchRow(1, 80)));
      await pumpThroughDatabase(tester);
      expect(find.text('at /clip'), findsOneWidget,
          reason: 'no frame is a missing picture, not a missing clip');

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
