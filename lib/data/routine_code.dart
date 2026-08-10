/// A whole training program squeezed into one line of text.
///
/// ```
/// FLR2.AeNiYGBgZGRkYWBhZWBgY2BgYWJgYGZgYGVgYGdgYGFiYGBmYmBgZWJgYGdiYGBhYWBgZmFg…
/// ```
///
/// ## Why a format at all
///
/// A routine is a program, its days, every exercise slot in every day with
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
/// Two things are simply not carried. One is an exercise's coaching cue. It was the
/// largest field on the row and the least worth the space — the recipient can
/// read the movement's name, and the video link that *does* travel shows them
/// the rest. That link travels as its eleven-character id rather than as a URL,
/// which is why a search results page (no video behind it) travels as nothing.
///
/// The other is **every suggested weight**. Someone else's working load is the
/// one number in a program that is certainly wrong for the person importing it,
/// so a slot travels with its whole prescription — sets, reps, rest, axis, step
/// and back-off rates, thresholds — and no weight at all. The importing phone
/// fills that in from its own history; see `routine_import.dart`.
///
/// ## The wire format
///
/// `FLR2` is a **format** version, not an app version: a future `FLR3` may
/// change everything below, and this reader declines anything not tagged `FLR1`
/// or `FLR2` rather than mangling it. The envelope — the tag, the base64, the
/// CRC-32, the link unwrapping, the failure cases — is [ShareCodec], shared with
/// the theme format.
///
/// **`FLR1` is read and never written.** Its body is what follows, minus the two
/// muscle lists: it had one byte for one muscle group, and a movement can work
/// several. The bit that introduces the lists was unused in `FLR1`, so the same
/// reader handles both and an `FLR1` exercise arrives with its one group as its
/// only primary. The tag still had to move: a phone on the shipped build would
/// otherwise read those lists as the next exercise's flags.
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
///   byte    lead muscle group: an index into kMuscleGroups + 1, or 0 + a string
///   byte    equipment: the same, over kEquipmentTypes
///   varint  further primary groups, then that many words — only with _exMuscles
///   varint  secondary groups, then that many words — only with _exMuscles
///   string  video id       — 11 chars, only when a link resolves to a video
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
/// There is no weight field in a slot, by design — see above.
///
/// **The orders are frozen**: the field bits, the exercise flag bits, and the
/// two vocabularies. Reordering any of them silently re-reads every code
/// already shared. Appending is safe — a reader that stops early simply ignores
/// what it does not know, and unknown trailing bytes are covered by the
/// checksum but never parsed.
///
/// ## What deliberately does not travel
///
/// The sender's progression streaks, their reminder time and their weights. All
/// three are facts about the sender rather than about the program: a streak is
/// momentum you have to earn on your own bar, a notification is something a
/// person asks for rather than inherits, and a working weight belongs to the
/// body doing the work.
library;

import 'package:archive/archive.dart' show Deflate, DeflateLevel, Inflate;

import '../util/qr_capacity.dart';
import '../util/video_links.dart';
import 'exercise_taxonomy.dart';
import 'plates.dart';
import 'progression.dart';
import 'set_scheme.dart';
import 'share_code.dart';

/// One exercise as it travels: enough to find it in the recipient's library, or
/// to build it there if they have never had it.
class SharedExercise {
  const SharedExercise({
    required this.name,
    required this.muscles,
    required this.equipment,
    required this.isCustom,
    required this.measure,
    required this.weightType,
    this.videoUrl,
    this.barWeight,
  });

  final String name;

  /// Every group the movement works, trained and assisted — see [MuscleMap].
  /// An `FLR1` code could only say one, and arrives as that one primary.
  final MuscleMap muscles;

  final String equipment;

  /// Whether the sender built this one themselves. A starter-library movement
  /// is on the recipient's phone already, so it travels as a name and is
  /// matched rather than copied; a custom one travels whole.
  final bool isCustom;

  final ExerciseMeasure measure;
  final WeightType weightType;

  /// A link to the movement, always in canonical `https://youtu.be/<id>` form —
  /// see [youTubeVideoId] for what does and does not survive the trip. Null
  /// when the sender had none, or had one with no video behind it.
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
    ProgressionMode progression = ProgressionMode.weight,
    int holdSeconds = 30,
    double? increment,
    double? deload,
    int successThreshold = defaultSuccessThreshold,
    int failureThreshold = defaultFailureThreshold,
    SetScheme scheme = SetScheme.flat,
    int schemePercent = kDefaultSchemePercent,
    List<CustomSet> customSets = const [],
  }) =>
      SharedItem._(
        exercise: exercise,
        targetSets: targetSets,
        repsMin: repsMin,
        repsMax: repsMax,
        toFailure: toFailure,
        restSeconds: restSeconds,
        progression: progression,
        holdSeconds: holdSeconds,
        increment: increment ?? progression.defaultIncrement,
        deload: deload ?? progression.defaultDeload,
        successThreshold: successThreshold,
        failureThreshold: failureThreshold,
        scheme: scheme,
        schemePercent: schemePercent,
        customSets: customSets,
      );

  const SharedItem._({
    required this.exercise,
    required this.targetSets,
    required this.repsMin,
    required this.repsMax,
    required this.toFailure,
    required this.restSeconds,
    required this.progression,
    required this.holdSeconds,
    required this.increment,
    required this.deload,
    required this.successThreshold,
    required this.failureThreshold,
    required this.scheme,
    required this.schemePercent,
    required this.customSets,
  });

  /// Index into [SharedRoutine.exercises].
  final int exercise;

  final int targetSets;
  final int repsMin;
  final int? repsMax;
  final bool toFailure;
  final int? restSeconds;
  final ProgressionMode progression;
  final int holdSeconds;
  final int successThreshold;
  final int failureThreshold;

  /// How far the target steps, and how far it backs off, in the mode's own unit.
  final double increment;
  final double deload;

  /// The shape of the slot's sets, and the percentages that shape is made of.
  ///
  /// The shape travels rather than the weights it produces — which is what lets
  /// the ladder arrive already snapped to the *receiving* phone's unit, the
  /// same way a step rate does.
  final SetScheme scheme;
  final int schemePercent;
  final List<CustomSet> customSets;
}

/// One training day as it travels.
class SharedWorkout {
  const SharedWorkout({required this.name, required this.items});
  final String name;
  final List<SharedItem> items;
}

/// A whole program, ready to encode or to land in a database.
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

  /// The weekday bitmask from `schedule.dart`. Part of the program — "this is
  /// a Monday/Wednesday/Friday split" is something the author decided.
  final int scheduleDays;

  /// Every exercise the routine references, in first-use order. Slots point
  /// here by index.
  final List<SharedExercise> exercises;

  final List<SharedWorkout> workouts;
}

/// Reads and writes the routine code. See the library docs above.
abstract final class RoutineCode {
  /// The tag every code this build writes carries.
  static const String version = 'FLR2';

  /// The tags this build reads. `FLR1` is the shipped format: it could hold one
  /// muscle group per exercise and nothing this build writes fits in it, but the
  /// codes written under it are in messages people can still open, so it is read
  /// and never written. See [_readMuscles].
  static const Set<String> readableVersions = {version, 'FLR1'};

  /// The link host a routine lives under: `fosslift://routine/<code>`.
  static const String host = 'routine';

  /// The longest link a QR code can hold at all — a version-40 symbol at low
  /// error correction. See `util/qr_capacity.dart` for where the number comes
  /// from and what it costs.
  static const int qrLinkLimit = kQrBytesLowEcc;

  /// The longest name a code will carry, in UTF-8 bytes.
  ///
  /// Generous next to the 80 characters the database enforces, so a name that
  /// is legal in the app never loses characters here first — and bounded all
  /// the same, so a corrupt or hostile code cannot claim a megabyte of routine
  /// name and be believed. Names past it are cut rather than rejected: losing
  /// the tail of a label is a smaller harm than refusing the whole program.
  static const int maxNameBytes = 200;

  /// Cuts [name] to [maxNameBytes], on a boundary that still decodes.
  static String _clampName(String name) {
    if (name.length <= maxNameBytes) return name;
    return name.substring(0, maxNameBytes);
  }

  /// Whether [link] fits in a QR code. Past this the routine is still perfectly
  /// shareable as a code you paste — an honest "too big for a QR" beats painting
  /// a symbol nothing can read.
  static bool fitsQr(String link) => qrHolds(link.length);

  // -- Exercise flag bits ---------------------------------------------------
  // **Frozen.** These numbers are in codes people are holding. Append at the
  // top only; never reorder, never renumber, never reuse a retired bit. The
  // renumbering that happened before the first release is history, not licence.
  // A change these bits cannot express is an `FLR2`, with this reader kept.
  static const int _exCustom = 1 << 0;
  static const int _exVideo = 1 << 1;
  static const int _exTimed = 1 << 2;
  static const int _exWeightType = 1 << 3;
  static const int _exBarWeight = 1 << 4;

  /// Set when the movement works more than the one group the lead byte carries.
  /// Unused by anything that wrote `FLR1`, which is why an `FLR1` body reads
  /// correctly through the same code — and why a single-group routine costs the
  /// same in `FLR2` as it did before.
  static const int _exMuscles = 1 << 5;

  // -- Slot field bits (read in ascending order) ----------------------------
  // **Frozen**, on the same terms as the exercise bits above: append only. Bit
  // 5 was the suggested weight and the bits above it were renumbered down when
  // weights stopped travelling — which was before any code existed to break.
  static const int _fSets = 1 << 0;
  static const int _fRepsMin = 1 << 1;
  static const int _fRepsMax = 1 << 2;
  static const int _fToFailure = 1 << 3;
  static const int _fRest = 1 << 4;
  static const int _fProgression = 1 << 5;
  static const int _fHold = 1 << 6;
  static const int _fIncrement = 1 << 7;
  static const int _fDeload = 1 << 8;
  static const int _fSuccess = 1 << 9;
  static const int _fFailure = 1 << 10;
  static const int _fScheme = 1 << 11;
  static const int _fCustomSets = 1 << 12;

  /// Deflate without the zlib wrapper — six bytes of header and checksum this
  /// format already provides for itself.
  ///
  /// Pure Dart rather than `dart:io`'s `ZLibCodec`, because the app also builds
  /// for the browser and `dart:io` compiles there and then throws from every
  /// call. The output is ordinary deflate either way — byte for byte the same
  /// length in practice, and each decodes the other's — so `FLR1` means one
  /// thing on every platform and a code does not carry which build wrote it.
  static List<int> _deflate(List<int> raw) =>
      Deflate(raw, level: DeflateLevel.bestCompression).takeBytes();

  static List<int> _inflate(List<int> packed) => Inflate(packed).getBytes();

  /// Encodes [routine] as a shareable code.
  static String encode(SharedRoutine routine) {
    final body = ByteWriter();
    body.string(_clampName(routine.name));
    body.bytes(_rgb(routine.colorHex));
    body.varint(routine.restSeconds);
    body.varint(routine.scheduleDays);

    body.varint(routine.exercises.length);
    for (final e in routine.exercises) {
      // Eleven characters, or nothing: a link we cannot resolve to a video is a
      // page, and a page is not worth the ninety bytes it costs.
      final videoId =
          e.videoUrl == null ? null : youTubeVideoId(e.videoUrl!);
      // Only worth sending when it is not what this equipment implies anyway.
      final typed = e.weightType != weightTypeForEquipment(e.equipment);

      // The lead group is all an FLR1 code could hold; everything past it costs
      // the flag bit and the two lists below.
      final beyondLead =
          e.muscles.extraPrimary.isNotEmpty || e.muscles.secondary.isNotEmpty;

      body.byte((e.isCustom ? _exCustom : 0) |
          (videoId != null ? _exVideo : 0) |
          (e.measure == ExerciseMeasure.time ? _exTimed : 0) |
          (typed ? _exWeightType : 0) |
          (e.barWeight != null ? _exBarWeight : 0) |
          (beyondLead ? _exMuscles : 0));
      body.string(_clampName(e.name));
      _writeWord(body, e.muscles.lead, kMuscleGroups);
      _writeWord(body, e.equipment, kEquipmentTypes);
      if (beyondLead) {
        for (final list in [e.muscles.extraPrimary, e.muscles.secondary]) {
          body.varint(list.length);
          for (final group in list) {
            _writeWord(body, group, kMuscleGroups);
          }
        }
      }
      if (videoId != null) body.string(videoId);
      if (typed) body.byte(e.weightType.index);
      if (e.barWeight != null) body.fixed2(e.barWeight!);
    }

    body.varint(routine.workouts.length);
    for (final w in routine.workouts) {
      body.string(_clampName(w.name));
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
    final packed = _deflate(raw);
    final smaller = packed.length < raw.length;

    return ShareCodec.pack(
      version,
      [smaller ? 0x01 : 0x00, ...(smaller ? packed : raw)],
      checksumBytes: 4,
    );
  }

  /// The full share link — what a **QR code** holds, so one image serves both a
  /// system camera (which routes the scheme to the app) and the in-app scanner
  /// (which strips the prefix and imports directly).
  ///
  /// The share *sheet* sends [encode] instead: a chat app does not linkify a
  /// custom scheme, so a link in a message is unclickable text carrying a prefix
  /// the reader has to strip. A camera has no such trouble with one.
  static String link(SharedRoutine routine) =>
      '${ShareCodec.linkPrefix(host)}${encode(routine)}';

  /// Reads a code, a share link, or either with whitespace through it.
  ///
  /// Never throws and never returns half a routine: the result is either a
  /// [RoutineCodeOk] with a complete program or a [RoutineCodeFailure] saying
  /// which of the three things went wrong.
  static RoutineCodeResult decode(String source) {
    final read = ShareCodec.unpack(source,
        versions: readableVersions, host: host, minBody: 2, checksumBytes: 4);
    if (read.problem != null) return RoutineCodeFailure(read.problem!);

    final envelope = read.body!;
    List<int> raw;
    try {
      raw = envelope[0] & 0x01 != 0
          ? _inflate(envelope.sublist(1))
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
    final name = _clampName(r.string());
    final color = _hex(r.byte(), r.byte(), r.byte());
    final rest = r.varint();
    final days = r.varint();

    final exercises = <SharedExercise>[];
    final exerciseCount = r.varint();
    for (var i = 0; i < exerciseCount; i++) {
      final flags = r.byte();
      final exName = _clampName(r.string());
      final lead = _readWord(r, kMuscleGroups);
      final equipment = _readWord(r, kEquipmentTypes);
      final muscles = _readMuscles(r, lead, flags);
      // Read in wire order, into locals: the fields are positional in the byte
      // stream even though they are named in the constructor.
      final video = flags & _exVideo != 0 ? youTubeUrl(r.string()) : null;
      final weightType = flags & _exWeightType != 0
          ? _weightType(r.byte())
          : weightTypeForEquipment(equipment);
      final barWeight = flags & _exBarWeight != 0 ? r.fixed2() : null;

      exercises.add(SharedExercise(
        name: exName,
        muscles: muscles,
        equipment: equipment,
        isCustom: flags & _exCustom != 0,
        measure: flags & _exTimed != 0
            ? ExerciseMeasure.time
            : ExerciseMeasure.reps,
        videoUrl: video,
        weightType: weightType,
        barWeight: barWeight,
      ));
    }

    final workouts = <SharedWorkout>[];
    final workoutCount = r.varint();
    for (var i = 0; i < workoutCount; i++) {
      final dayName = _clampName(r.string());
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
    if (it.progression != plain.progression) mask |= _fProgression;
    if (it.holdSeconds != plain.holdSeconds) mask |= _fHold;
    if (it.increment != it.progression.defaultIncrement) mask |= _fIncrement;
    if (it.deload != it.progression.defaultDeload) mask |= _fDeload;
    if (it.successThreshold != plain.successThreshold) mask |= _fSuccess;
    if (it.failureThreshold != plain.failureThreshold) mask |= _fFailure;
    if (it.scheme != plain.scheme || it.schemePercent != plain.schemePercent) {
      mask |= _fScheme;
    }
    if (it.customSets.isNotEmpty) mask |= _fCustomSets;

    out.varint(mask);
    if (mask & _fSets != 0) out.varint(it.targetSets);
    if (mask & _fRepsMin != 0) out.varint(it.repsMin);
    if (mask & _fRepsMax != 0) out.varint(it.repsMax!);
    if (mask & _fRest != 0) out.varint(it.restSeconds!);
    if (mask & _fProgression != 0) out.byte(it.progression.index);
    if (mask & _fHold != 0) out.varint(it.holdSeconds);
    if (mask & _fIncrement != 0) out.fixed2(it.increment);
    if (mask & _fDeload != 0) out.fixed2(it.deload);
    if (mask & _fSuccess != 0) out.varint(it.successThreshold);
    if (mask & _fFailure != 0) out.varint(it.failureThreshold);
    if (mask & _fScheme != 0) {
      out.byte(it.scheme.index);
      out.varint(it.schemePercent);
    }
    // Each row is a pair, so one count and twice that many varints. Only a
    // custom slot ever writes any.
    if (mask & _fCustomSets != 0) {
      out.varint(it.customSets.length);
      for (final row in it.customSets) {
        out.varint(row.reps);
        out.varint(row.percent);
      }
    }
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
    final mode =
        mask & _fProgression != 0 ? _progression(r.byte()) : plain.progression;
    final hold = mask & _fHold != 0 ? r.varint() : plain.holdSeconds;
    final increment = mask & _fIncrement != 0 ? r.fixed2() : null;
    final deload = mask & _fDeload != 0 ? r.fixed2() : null;
    final success =
        mask & _fSuccess != 0 ? r.varint() : plain.successThreshold;
    final failure =
        mask & _fFailure != 0 ? r.varint() : plain.failureThreshold;
    final scheme = mask & _fScheme != 0 ? _scheme(r.byte()) : plain.scheme;
    final schemePercent =
        mask & _fScheme != 0 ? r.varint() : plain.schemePercent;
    final custom = <CustomSet>[];
    if (mask & _fCustomSets != 0) {
      final rows = r.varint();
      for (var i = 0; i < rows; i++) {
        custom.add(CustomSet(reps: r.varint(), percent: r.varint()));
      }
    }

    return SharedItem(
      exercise: exercise,
      targetSets: sets,
      repsMin: repsMin,
      repsMax: repsMax,
      toFailure: mask & _fToFailure != 0,
      restSeconds: rest,
      progression: mode,
      holdSeconds: hold,
      increment: increment,
      deload: deload,
      successThreshold: success,
      failureThreshold: failure,
      scheme: scheme,
      schemePercent: schemePercent,
      customSets: custom,
    );
  }

  /// A scheme by its index, or flat for one this build has never heard of —
  /// the same forgiveness the progression axis gets.
  static SetScheme _scheme(int index) => index >= 0 &&
          index < SetScheme.values.length
      ? SetScheme.values[index]
      : SetScheme.flat;

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

  /// The muscle map of the exercise being read: the lead group already off the
  /// wire, plus the two lists that follow it when [_exMuscles] is set.
  ///
  /// An `FLR1` code never set that bit, so this is also how a code written
  /// before a movement could work more than one group arrives — as the single
  /// primary it always meant.
  static MuscleMap _readMuscles(ByteReader r, String lead, int flags) {
    if (flags & _exMuscles == 0) return MuscleMap.single(lead);
    final lists = [
      for (var list = 0; list < 2; list++)
        [for (var i = r.varint(); i > 0; i--) _readWord(r, kMuscleGroups)],
    ];
    return MuscleMap(primary: [lead, ...lists[0]], secondary: lists[1]);
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
}
