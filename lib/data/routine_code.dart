/// A whole training programme squeezed into one line of text.
///
/// ```
/// FLR1.AeNiYGBgZGRkYWBhZWBgY2BgYWJgYGZgYGVgYGdgYGFiYGBmYmBgZWJgYGdiYGBhYWBgZmFg…
/// ```
///
/// ## Why a format at all
///
/// A routine is a programme, its days, every exercise slot in every day with
/// its full configuration, and the definition of every exercise it leans on —
/// including the custom ones the recipient has never heard of. As JSON that is
/// several kilobytes and quite unshareable. This gets the PPL demo routine to
/// 421 characters, which fits in a QR code and a chat message alike.
///
/// Three things do the squeezing, in order of how much they win:
///
/// 1. **Defaults are not sent.** Each slot carries a bitmask of the fields that
///    actually differ from the app's defaults, and nothing else. A routine of
///    ordinary 3×8 slots spends two bytes on each.
/// 2. **Words become numbers.** Muscle groups and equipment kinds are indices
///    into [kMuscleGroups] / [kEquipmentTypes]; exercises are a dictionary at
///    the front that the slots reference by index, so "Bench Press" is written
///    once however many days press.
/// 3. **The rest is deflated**, when deflating actually helps — a short routine
///    is often smaller raw, and the flag byte says which happened.
///
/// ## The wire format
///
/// `FLR1` is a **format** version, not an app version: a future `FLR2` may
/// change everything below and this reader will decline it with "made by a
/// newer version" rather than mangling it. The envelope — the tag, the base64,
/// the CRC-32, the link unwrapping, the three failure cases — is [ShareCodec],
/// shared with the theme format.
///
/// Inside the envelope: one flag byte (bit 0: the rest is deflated), then the
/// body, raw or deflated:
///
/// ```
/// string  routine name
/// 3 bytes colour, RGB
/// varint  default rest, seconds
/// varint  training-day mask
/// varint  exercise count, then that many exercises:
///   byte    flags — see the _ex* constants
///   string  name
///   byte    muscle group: an index into kMuscleGroups + 1, or 0 + a string
///   byte    equipment: the same, over kEquipmentTypes
///   string  instructions   — custom exercises only
///   string  video URL      — custom exercises only, and only if it has one
///   byte    weight type    — only when it is not the default for the equipment
///   varint  bar weight ×100
/// varint  workout count, then that many workouts:
///   string  name
///   varint  slot count, then that many slots:
///     varint  exercise index
///     varint  field mask — see the _f* constants
///     …only the fields the mask names, in bit order
/// ```
///
/// **The orders are frozen**: the field bits, the exercise flag bits, and the
/// two vocabularies. Reordering any of them silently re-reads every code
/// already shared. Appending is safe — a reader that stops early simply ignores
/// what it does not know, and unknown trailing bytes are covered by the
/// checksum but never parsed.
///
/// ## What deliberately does not travel
///
/// The sender's progression streaks and their reminder time. Both are facts
/// about the sender rather than about the programme: a streak is momentum you
/// have to earn on your own bar, and a notification is something a person asks
/// for rather than inherits.
library;

import 'dart:io';

import 'exercise_taxonomy.dart';
import 'plates.dart';
import 'progression.dart';
import 'share_code.dart';

/// One exercise as it travels: enough to find it in the recipient's library, or
/// to build it there if they have never had it.
class SharedExercise {
  const SharedExercise({
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.isCustom,
    required this.measure,
    required this.weightType,
    this.instructions = '',
    this.videoUrl,
    this.barWeight,
  });

  final String name;
  final String muscleGroup;
  final String equipment;

  /// Whether the sender built this one themselves. A starter-library movement
  /// is on the recipient's phone already, so it travels as a name and is
  /// matched rather than copied; a custom one travels whole.
  final bool isCustom;

  final ExerciseMeasure measure;
  final WeightType weightType;

  /// The coaching cue. Empty for a built-in — the recipient has their own copy.
  final String instructions;
  final String? videoUrl;

  /// What this movement's own bar weighs, in kg, when the sender said it
  /// differs from their default. Null is "whatever the recipient's default is".
  final double? barWeight;
}

/// One exercise slot as it travels. Every field is the value that should end up
/// on the recipient's row — the decoder has already filled in the defaults the
/// sender did not spend bytes on.
class SharedItem {
  /// A null [increment] or [deload] takes the default for [progression] rather
  /// than one fixed number: a rep-progressed pull-up steps by 1, not by 2.5 kg.
  factory SharedItem({
    required int exercise,
    int targetSets = 3,
    int repsMin = 8,
    int? repsMax,
    bool toFailure = false,
    int? restSeconds,
    double? suggestedWeight,
    ProgressionMode progression = ProgressionMode.weight,
    int holdSeconds = 30,
    double? increment,
    double? deload,
    int successThreshold = defaultSuccessThreshold,
    int failureThreshold = defaultFailureThreshold,
  }) =>
      SharedItem._(
        exercise: exercise,
        targetSets: targetSets,
        repsMin: repsMin,
        repsMax: repsMax,
        toFailure: toFailure,
        restSeconds: restSeconds,
        suggestedWeight: suggestedWeight,
        progression: progression,
        holdSeconds: holdSeconds,
        increment: increment ?? progression.defaultIncrement,
        deload: deload ?? progression.defaultDeload,
        successThreshold: successThreshold,
        failureThreshold: failureThreshold,
      );

  const SharedItem._({
    required this.exercise,
    required this.targetSets,
    required this.repsMin,
    required this.repsMax,
    required this.toFailure,
    required this.restSeconds,
    required this.suggestedWeight,
    required this.progression,
    required this.holdSeconds,
    required this.increment,
    required this.deload,
    required this.successThreshold,
    required this.failureThreshold,
  });

  /// Index into [SharedRoutine.exercises].
  final int exercise;

  final int targetSets;
  final int repsMin;
  final int? repsMax;
  final bool toFailure;
  final int? restSeconds;
  final double? suggestedWeight;
  final ProgressionMode progression;
  final int holdSeconds;
  final int successThreshold;
  final int failureThreshold;

  /// How far the target steps, and how far it backs off, in the mode's own unit.
  final double increment;
  final double deload;
}

/// One training day as it travels.
class SharedWorkout {
  const SharedWorkout({required this.name, required this.items});
  final String name;
  final List<SharedItem> items;
}

/// A whole programme, ready to encode or to land in a database.
class SharedRoutine {
  const SharedRoutine({
    required this.name,
    required this.colorHex,
    required this.restSeconds,
    required this.scheduleDays,
    required this.exercises,
    required this.workouts,
  });

  final String name;
  final String colorHex;
  final int restSeconds;

  /// The weekday bitmask from `schedule.dart`. Part of the programme — "this is
  /// a Monday/Wednesday/Friday split" is something the author decided.
  final int scheduleDays;

  /// Every exercise the routine references, in first-use order. Slots point
  /// here by index.
  final List<SharedExercise> exercises;

  final List<SharedWorkout> workouts;
}

/// Reads and writes the `FLR1` routine code. See the library docs above.
abstract final class RoutineCode {
  /// The current format tag. Bump only for a layout change this reader could
  /// not otherwise survive — appended fields do not need it.
  static const String version = 'FLR1';

  /// The link host a routine lives under: `fosslift://routine/<code>`.
  static const String host = 'routine';

  /// The longest link still worth painting as a QR code.
  ///
  /// Past this a symbol needs so many modules that a phone screen photographed
  /// by another phone stops decoding reliably, and an unscannable QR is worse
  /// than an honest "this one is too big — send the link". Roughly a version-25
  /// symbol at medium error correction.
  static const int qrLinkLimit = 900;

  /// Whether [link] is short enough to be worth showing as a QR code.
  static bool fitsQr(String link) => link.length <= qrLinkLimit;

  // -- Exercise flag bits (frozen) ------------------------------------------
  static const int _exCustom = 1 << 0;
  static const int _exInstructions = 1 << 1;
  static const int _exVideo = 1 << 2;
  static const int _exTimed = 1 << 3;
  static const int _exWeightType = 1 << 4;
  static const int _exBarWeight = 1 << 5;

  // -- Slot field bits (frozen; read in ascending order) --------------------
  static const int _fSets = 1 << 0;
  static const int _fRepsMin = 1 << 1;
  static const int _fRepsMax = 1 << 2;
  static const int _fToFailure = 1 << 3;
  static const int _fRest = 1 << 4;
  static const int _fWeight = 1 << 5;
  static const int _fProgression = 1 << 6;
  static const int _fHold = 1 << 7;
  static const int _fIncrement = 1 << 8;
  static const int _fDeload = 1 << 9;
  static const int _fSuccess = 1 << 10;
  static const int _fFailure = 1 << 11;

  /// Deflate without the zlib wrapper — six bytes of header and checksum this
  /// format already provides for itself.
  static final ZLibCodec _deflate = ZLibCodec(raw: true, level: 9);

  /// Encodes [routine] as a shareable code.
  static String encode(SharedRoutine routine) {
    final body = ByteWriter();
    body.string(routine.name);
    body.bytes(_rgb(routine.colorHex));
    body.varint(routine.restSeconds);
    body.varint(routine.scheduleDays);

    body.varint(routine.exercises.length);
    for (final e in routine.exercises) {
      final hasVideo = e.isCustom && (e.videoUrl?.isNotEmpty ?? false);
      final hasInstructions = e.isCustom && e.instructions.isNotEmpty;
      // Only worth sending when it is not what this equipment implies anyway.
      final typed = e.weightType != weightTypeForEquipment(e.equipment);

      body.byte((e.isCustom ? _exCustom : 0) |
          (hasInstructions ? _exInstructions : 0) |
          (hasVideo ? _exVideo : 0) |
          (e.measure == ExerciseMeasure.time ? _exTimed : 0) |
          (typed ? _exWeightType : 0) |
          (e.barWeight != null ? _exBarWeight : 0));
      body.string(e.name);
      _writeWord(body, e.muscleGroup, kMuscleGroups);
      _writeWord(body, e.equipment, kEquipmentTypes);
      if (hasInstructions) body.string(e.instructions);
      if (hasVideo) body.string(e.videoUrl!);
      if (typed) body.byte(e.weightType.index);
      if (e.barWeight != null) body.fixed2(e.barWeight!);
    }

    body.varint(routine.workouts.length);
    for (final w in routine.workouts) {
      body.string(w.name);
      body.varint(w.items.length);
      for (final it in w.items) {
        body.varint(it.exercise);
        _writeItem(body, it);
      }
    }

    final raw = body.take();
    // Compress only when it actually helps: a short routine of common words
    // deflates to more than it started as, and paying for that in QR density
    // would be silly.
    final packed = _deflate.encode(raw);
    final smaller = packed.length < raw.length;

    return ShareCodec.pack(
      version,
      [smaller ? 0x01 : 0x00, ...(smaller ? packed : raw)],
      checksumBytes: 4,
    );
  }

  /// The full share link — what a QR code holds, so one image serves both a
  /// system camera (which routes the scheme to the app) and the in-app scanner
  /// (which strips the prefix and imports directly).
  static String link(SharedRoutine routine) =>
      '${ShareCodec.linkPrefix(host)}${encode(routine)}';

  /// Reads a code, a share link, or either with whitespace through it.
  ///
  /// Never throws and never returns half a routine: the result is either a
  /// [RoutineCodeOk] with a complete programme or a [RoutineCodeFailure] saying
  /// which of the three things went wrong.
  static RoutineCodeResult decode(String source) {
    final read = ShareCodec.unpack(source,
        version: version, host: host, minBody: 2, checksumBytes: 4);
    if (read.problem != null) return RoutineCodeFailure(read.problem!);

    final envelope = read.body!;
    List<int> raw;
    try {
      raw = envelope[0] & 0x01 != 0
          ? _deflate.decode(envelope.sublist(1))
          : envelope.sublist(1);
    } catch (_) {
      return const RoutineCodeFailure(ShareCodeProblem.damaged);
    }

    try {
      return RoutineCodeOk(_read(ByteReader(raw)));
    } on ShareCodeDamaged {
      return const RoutineCodeFailure(ShareCodeProblem.damaged);
    } on RangeError {
      return const RoutineCodeFailure(ShareCodeProblem.damaged);
    }
  }

  static SharedRoutine _read(ByteReader r) {
    final name = r.string();
    final color = _hex(r.byte(), r.byte(), r.byte());
    final rest = r.varint();
    final days = r.varint();

    final exercises = <SharedExercise>[];
    final exerciseCount = r.varint();
    for (var i = 0; i < exerciseCount; i++) {
      final flags = r.byte();
      final exName = r.string();
      final muscle = _readWord(r, kMuscleGroups);
      final equipment = _readWord(r, kEquipmentTypes);
      // Read in wire order, into locals: the fields are positional in the byte
      // stream even though they are named in the constructor.
      final instructions = flags & _exInstructions != 0 ? r.string() : '';
      final video = flags & _exVideo != 0 ? r.string() : null;
      final weightType = flags & _exWeightType != 0
          ? _weightType(r.byte())
          : weightTypeForEquipment(equipment);
      final barWeight = flags & _exBarWeight != 0 ? r.fixed2() : null;

      exercises.add(SharedExercise(
        name: exName,
        muscleGroup: muscle,
        equipment: equipment,
        isCustom: flags & _exCustom != 0,
        measure: flags & _exTimed != 0
            ? ExerciseMeasure.time
            : ExerciseMeasure.reps,
        instructions: instructions,
        videoUrl: video,
        weightType: weightType,
        barWeight: barWeight,
      ));
    }

    final workouts = <SharedWorkout>[];
    final workoutCount = r.varint();
    for (var i = 0; i < workoutCount; i++) {
      final dayName = r.string();
      final items = <SharedItem>[];
      final itemCount = r.varint();
      for (var j = 0; j < itemCount; j++) {
        final index = r.varint();
        // A slot pointing outside the dictionary is a code we cannot honour
        // without inventing an exercise.
        if (index >= exercises.length) throw const ShareCodeDamaged();
        items.add(_readItem(r, index));
      }
      workouts.add(SharedWorkout(name: dayName, items: items));
    }
    // Anything after this belongs to a later revision of FLR1 — ignored on
    // purpose, but still covered by the checksum. See the library docs.

    return SharedRoutine(
      name: name.trim().isEmpty ? 'Shared routine' : name,
      colorHex: color,
      restSeconds: rest,
      scheduleDays: days,
      exercises: exercises,
      workouts: workouts,
    );
  }

  /// Writes a slot as a mask of what differs from the defaults, then those
  /// fields. The mode is written before the increment and deload it decides the
  /// defaults for, so the reader knows which defaults it is filling in.
  static void _writeItem(ByteWriter out, SharedItem it) {
    final plain = SharedItem(exercise: 0);
    var mask = 0;
    if (it.targetSets != plain.targetSets) mask |= _fSets;
    if (it.repsMin != plain.repsMin) mask |= _fRepsMin;
    if (it.repsMax != null) mask |= _fRepsMax;
    if (it.toFailure) mask |= _fToFailure;
    if (it.restSeconds != null) mask |= _fRest;
    if (it.suggestedWeight != null) mask |= _fWeight;
    if (it.progression != plain.progression) mask |= _fProgression;
    if (it.holdSeconds != plain.holdSeconds) mask |= _fHold;
    if (it.increment != it.progression.defaultIncrement) mask |= _fIncrement;
    if (it.deload != it.progression.defaultDeload) mask |= _fDeload;
    if (it.successThreshold != plain.successThreshold) mask |= _fSuccess;
    if (it.failureThreshold != plain.failureThreshold) mask |= _fFailure;

    out.varint(mask);
    if (mask & _fSets != 0) out.varint(it.targetSets);
    if (mask & _fRepsMin != 0) out.varint(it.repsMin);
    if (mask & _fRepsMax != 0) out.varint(it.repsMax!);
    if (mask & _fRest != 0) out.varint(it.restSeconds!);
    if (mask & _fWeight != 0) out.fixed2(it.suggestedWeight!);
    if (mask & _fProgression != 0) out.byte(it.progression.index);
    if (mask & _fHold != 0) out.varint(it.holdSeconds);
    if (mask & _fIncrement != 0) out.fixed2(it.increment);
    if (mask & _fDeload != 0) out.fixed2(it.deload);
    if (mask & _fSuccess != 0) out.varint(it.successThreshold);
    if (mask & _fFailure != 0) out.varint(it.failureThreshold);
  }

  static SharedItem _readItem(ByteReader r, int exercise) {
    final plain = SharedItem(exercise: 0);
    final mask = r.varint();

    // Strictly in bit order — the mask says which fields are there, and the
    // fields themselves are positional.
    final sets = mask & _fSets != 0 ? r.varint() : plain.targetSets;
    final repsMin = mask & _fRepsMin != 0 ? r.varint() : plain.repsMin;
    final repsMax = mask & _fRepsMax != 0 ? r.varint() : null;
    final rest = mask & _fRest != 0 ? r.varint() : null;
    final weight = mask & _fWeight != 0 ? r.fixed2() : null;
    final mode =
        mask & _fProgression != 0 ? _progression(r.byte()) : plain.progression;
    final hold = mask & _fHold != 0 ? r.varint() : plain.holdSeconds;
    final increment = mask & _fIncrement != 0 ? r.fixed2() : null;
    final deload = mask & _fDeload != 0 ? r.fixed2() : null;
    final success =
        mask & _fSuccess != 0 ? r.varint() : plain.successThreshold;
    final failure =
        mask & _fFailure != 0 ? r.varint() : plain.failureThreshold;

    return SharedItem(
      exercise: exercise,
      targetSets: sets,
      repsMin: repsMin,
      repsMax: repsMax,
      toFailure: mask & _fToFailure != 0,
      restSeconds: rest,
      suggestedWeight: weight,
      progression: mode,
      holdSeconds: hold,
      increment: increment,
      deload: deload,
      successThreshold: success,
      failureThreshold: failure,
    );
  }

  /// A word from a frozen vocabulary as its index + 1, or 0 and the word
  /// spelled out — so a library exercise carrying something the app has never
  /// offered still travels.
  static void _writeWord(ByteWriter out, String word, List<String> vocabulary) {
    final at = vocabulary.indexOf(word);
    out.byte(at + 1);
    if (at < 0) out.string(word);
  }

  static String _readWord(ByteReader r, List<String> vocabulary) {
    final index = r.byte();
    if (index == 0) return r.string();
    if (index > vocabulary.length) throw const ShareCodeDamaged();
    return vocabulary[index - 1];
  }

  static List<int> _rgb(String hex) {
    final value = int.tryParse(hex, radix: 16) ?? 0xFF6A3D;
    return [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
  }

  static String _hex(int r, int g, int b) =>
      ((r << 16) | (g << 8) | b).toRadixString(16).toUpperCase().padLeft(6, '0');

  static WeightType _weightType(int index) => index < WeightType.values.length
      ? WeightType.values[index]
      : WeightType.machine;

  static ProgressionMode _progression(int index) =>
      index < ProgressionMode.values.length
          ? ProgressionMode.values[index]
          : ProgressionMode.weight;
}

/// What came of reading a routine code.
sealed class RoutineCodeResult {
  const RoutineCodeResult();
}

/// A code that read cleanly. [routine] is complete and safe to preview.
final class RoutineCodeOk extends RoutineCodeResult {
  const RoutineCodeOk(this.routine);
  final SharedRoutine routine;
}

/// A code that did not read, and why.
final class RoutineCodeFailure extends RoutineCodeResult {
  const RoutineCodeFailure(this.problem);
  final ShareCodeProblem problem;

  /// Wording for the user, in the shared phrasing — see [ShareCodeProblem].
  String get message => problem.message('routine');
}
