import 'dart:io';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'set_video_store.dart';

/// Pulls one frame out of the clip at [srcFile] and writes it to [destFile],
/// scaled to fit [width] × [height]. True if a frame was written.
///
/// A function rather than a class so the decoder can be swapped for a fake in
/// tests — the real one is a platform plugin and needs a device.
typedef ClipFrameDecoder = Future<bool> Function({
  required String srcFile,
  required String destFile,
  required int width,
  required int height,
});

/// The size a cached frame is decoded at — a bound on the reel's tile with
/// enough room for a dense screen, not the size it is drawn at.
const int kStillMaxSide = 320;

/// The frame each reel row shows, decoded once and kept beside its clip.
///
/// **Lazily, on first sight — not at record time.** A clip filmed before stills
/// existed still gets one the next time it is listed, and nothing is spent on a
/// clip nobody ever goes back to. The result is written to
/// `set_videos/<id>.jpg` (see [SetVideoStore.stillPathFor]), so one decode per
/// clip, ever, rather than one per build of the list.
///
/// The in-memory memo on top of the file is what makes that true *within* a
/// process, and it deliberately remembers failures too: a clip the decoder
/// cannot read stays unreadable, and retrying it on every frame is how a broken
/// clip ends up costing more than a working one.
class SetVideoThumbnails {
  SetVideoThumbnails(this._store, {ClipFrameDecoder? decode})
      : _decode = decode ?? _decodeNatively;

  final SetVideoStore _store;
  final ClipFrameDecoder _decode;

  /// One entry per clip asked about, holding the answer or the decode still in
  /// flight. The reel asks for every row at once on its first paint, so without
  /// this the same clip would be decoded once per asker.
  final Map<String, Future<File?>> _stills = {};

  /// The frame for the clip at [clipRelative], or null if there is not going to
  /// be one — the clip is gone, or the decoder cannot read it. Callers show the
  /// play symbol instead; a clip with no picture is still a clip.
  Future<File?> stillFor(String clipRelative) =>
      _stills.putIfAbsent(clipRelative, () => _generate(clipRelative));

  Future<File?> _generate(String clipRelative) async {
    final still = await _store.fileFor(_store.stillPathFor(clipRelative));
    if (await still.exists()) return still;

    final clip = await _store.fileFor(clipRelative);
    if (!await clip.exists()) return null;

    try {
      final made = await _decode(
        srcFile: clip.path,
        destFile: still.path,
        width: kStillMaxSide,
        height: kStillMaxSide,
      );
      if (made && await still.exists()) return still;
    } catch (_) {
      // A container the platform decoder will not open. Nothing about that is
      // worth interrupting the reel for.
    }
    // A half-written frame would be handed back for the rest of the install.
    if (await still.exists()) await still.delete();
    return null;
  }
}

final _plugin = FcNativeVideoThumbnail();

Future<bool> _decodeNatively({
  required String srcFile,
  required String destFile,
  required int width,
  required int height,
}) =>
    _plugin.saveThumbnailToFile(
      srcFile: srcFile,
      destFile: destFile,
      width: width,
      height: height,
      quality: 80,
    );

/// The reel's frames, on the same store the clips are in.
final setVideoThumbnailsProvider = Provider<SetVideoThumbnails>(
    (ref) => SetVideoThumbnails(ref.watch(setVideoStoreProvider)));
