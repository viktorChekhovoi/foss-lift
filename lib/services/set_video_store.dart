import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The heights a set clip can be filmed at. 720 is the default; 480 is for
/// people who would rather have the space.
///
/// 1080 is not on the list on purpose — see `Settings.videoHeight`.
const List<int> kVideoHeights = [480, 720];
const int kDefaultVideoHeight = 720;

/// The hard stops on one clip, in seconds — see `Settings.videoMaxSeconds`.
const List<int> kVideoMaxSeconds = [60, 180];
const int kDefaultVideoSeconds = 60;

/// Files older than this are fair game for the orphan sweep.
///
/// A clip recorded seconds ago has no row pointing at it yet — the live session
/// is in memory until Finish — so a sweep with no age guard would delete the
/// set the user is in the middle of filming.
const Duration kOrphanGrace = Duration(hours: 24);

/// Where set clips live on disk, and the only thing allowed to put them there
/// or take them away.
///
/// **Application Support, not Documents and not Temporary.** Temporary is
/// purged by iOS whenever it likes, and a clip nobody can re-shoot is not
/// regenerable. Documents becomes user-visible in the Files app the moment an
/// iOS build sets `UIFileSharingEnabled`, which would put footage of somebody
/// lifting next to their tax returns. Application Support cannot be browsed at
/// all, which is the right posture for this.
///
/// **Paths are stored relative** (`set_videos/<id>.mp4`) and joined onto a
/// freshly resolved directory on every use. The iOS container path contains a
/// UUID that changes on reinstall and on restore, so an absolute path stored
/// today is a dead pointer tomorrow — a bug that is completely invisible on
/// Android, which is why the rule is enforced here rather than remembered.
class SetVideoStore {
  SetVideoStore({Future<Directory> Function()? baseDirectory})
      : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory;

  /// Injected so tests can point the store at a temporary directory. Nothing
  /// in the app passes it.
  final Future<Directory> Function() _baseDirectory;

  /// The subfolder every clip lives in, and the first segment of every stored
  /// path.
  static const String folder = 'set_videos';

  final math.Random _random = math.Random();

  /// The clip folder, created if it is not there yet.
  Future<Directory> directory() async {
    final dir = Directory(p.join((await _baseDirectory()).path, folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// A relative path for a clip that does not exist yet.
  ///
  /// The name is a generated id — not a timestamp, which collides when two
  /// clips land in the same second, and not the exercise name, which would
  /// leak what somebody trains to anything that can list the directory.
  String newRelativePath() {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final salt = _random.nextInt(1 << 32).toRadixString(36);
    return p.join(folder, '$stamp$salt.mp4');
  }

  /// The file [relative] names, whether or not it exists.
  Future<File> fileFor(String relative) async =>
      File(p.join((await _baseDirectory()).path, relative));

  /// Whether the clip at [relative] is actually on disk. A row can outlive its
  /// file if one is removed by hand, and a play button for a file that is not
  /// there is worse than no play button.
  Future<bool> exists(String relative) async =>
      (await fileFor(relative)).exists();

  /// Moves a freshly recorded file into the store, returning its relative path.
  ///
  /// The camera writes wherever the platform plugin chooses; this is what puts
  /// it somewhere the app controls. A rename across filesystems throws, so it
  /// falls back to copying and then removing the original.
  Future<String> adopt(String recordedAbsolutePath) async {
    await directory();
    final relative = newRelativePath();
    final target = await fileFor(relative);
    final source = File(recordedAbsolutePath);
    try {
      await source.rename(target.path);
    } on FileSystemException {
      await source.copy(target.path);
      await source.delete();
    }
    return relative;
  }

  /// The still that belongs to the clip at [relative] — the same name with a
  /// `.jpg` on it, so the pairing needs no bookkeeping anywhere.
  ///
  /// Nothing in the database points at it. It is derived, regenerable and
  /// belongs to its clip absolutely: it is made when the clip is first listed
  /// and goes when the clip goes.
  String thumbnailFor(String relative) =>
      '${p.withoutExtension(relative)}.jpg';

  /// Removes the clip at [relative], and its still with it. A file that is
  /// already gone is not an error — deleting a clip twice should be as quiet as
  /// deleting it once.
  Future<void> delete(String relative) async {
    for (final path in [relative, thumbnailFor(relative)]) {
      final file = await fileFor(path);
      if (await file.exists()) await file.delete();
    }
  }

  /// Removes several clips, carrying on past any that will not go.
  Future<void> deleteAll(Iterable<String> relatives) async {
    for (final relative in relatives) {
      try {
        await delete(relative);
      } on FileSystemException {
        // A file the OS will not let go of leaks; it will be swept later. The
        // alternative — abandoning the rest of the list — leaks more.
      }
    }
  }

  /// Total bytes held by clips. What Settings shows, and what the threshold
  /// notice is measured against.
  Future<int> bytesUsed() async {
    var total = 0;
    for (final file in await _clipFiles()) {
      total += await file.length();
    }
    return total;
  }

  /// Deletes every clip on disk that no row points at, and returns how many
  /// went.
  ///
  /// This is the safety net for the one failure the ordering is designed to
  /// leave behind: writes go file-first, so a crash strands a file rather than
  /// stranding a row that points at nothing. [referenced] is every path held in
  /// `SessionSets.videoPath`.
  ///
  /// Files younger than [grace] are left alone — see [kOrphanGrace].
  Future<int> sweepOrphans(
    Set<String> referenced, {
    Duration grace = kOrphanGrace,
    DateTime? now,
  }) async {
    final cutoff = (now ?? DateTime.now()).subtract(grace);
    var removed = 0;
    final kept = <String>{};

    // Clips first. A still is not swept on its own account — nothing in the
    // database points at one, so judging it by the same rule would delete every
    // thumbnail on the first sweep.
    for (final file in await _clipFiles()) {
      if (p.extension(file.path) != '.mp4') continue;
      final relative = p.join(folder, p.basename(file.path));
      if (referenced.contains(relative)) {
        kept.add(relative);
        continue;
      }
      if ((await file.lastModified()).isAfter(cutoff)) {
        kept.add(relative);
        continue;
      }
      try {
        await delete(relative); // takes the still with it
        removed++;
      } on FileSystemException {
        // Leave it; the next sweep will try again.
        kept.add(relative);
      }
    }

    // Then any still whose clip is not there at all — the leftovers of a clip
    // removed by some route that did not go through [delete].
    for (final file in await _clipFiles()) {
      if (p.extension(file.path) != '.jpg') continue;
      final clip = p.join(folder, '${p.basenameWithoutExtension(file.path)}.mp4');
      if (kept.contains(clip)) continue;
      try {
        await file.delete();
      } on FileSystemException {
        // Same again: it will be caught next time.
      }
    }
    return removed;
  }

  /// Every file in the clip folder. Empty when the folder has never been made,
  /// which is the state of any install where nobody has filmed anything.
  Future<List<File>> _clipFiles() async {
    final dir = Directory(p.join((await _baseDirectory()).path, folder));
    if (!await dir.exists()) return const [];
    return dir.list().where((e) => e is File).cast<File>().toList();
  }
}

/// A size in bytes, said the way a storage screen says it.
String fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['kB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value < 10 ? value.toStringAsFixed(1) : value.round()} '
      '${units[unit]}';
}

/// Where set clips live on disk.
///
/// Declared beside the store rather than in `providers.dart` because the live
/// session needs it and `providers.dart` imports the live session — the same
/// shape, and the same reason, as `db_provider.dart`. Overridden in tests to
/// point at a temporary directory; nothing in the app overrides it.
final setVideoStoreProvider = Provider<SetVideoStore>((ref) => SetVideoStore());
