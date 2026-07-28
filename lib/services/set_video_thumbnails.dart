import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'set_video_store.dart';

/// How tall a reel thumbnail is drawn, in logical pixels. Generated at twice
/// that so it stays sharp on a 2× screen without storing a second copy of the
/// video's first frame at full size.
const int kThumbnailHeight = 72;

/// Pulls a still out of a clip.
///
/// An interface for the same reason [SetVideoRecorder] is one: decoding video
/// needs a platform, so a fake is what lets everything around it — where the
/// file goes, what happens when it cannot be made, whether it survives the
/// orphan sweep — be tested at all.
abstract class SetVideoThumbnailer {
  /// Writes a still from [video] to [target]. Returns false if no frame could
  /// be got, which is not an error worth surfacing: the reel falls back to an
  /// icon and the clip still plays.
  Future<bool> write({required String video, required String target});
}

class PluginThumbnailer implements SetVideoThumbnailer {
  @override
  Future<bool> write({required String video, required String target}) async {
    try {
      final written = await VideoThumbnail.thumbnailFile(
        video: video,
        thumbnailPath: target,
        imageFormat: ImageFormat.JPEG,
        maxHeight: kThumbnailHeight * 2,
        quality: 70,
      );
      return written != null && await File(written).exists();
    } catch (_) {
      // A clip the decoder will not open still plays, and still deserves a row.
      return false;
    }
  }
}

final thumbnailerProvider =
    Provider<SetVideoThumbnailer>((ref) => PluginThumbnailer());

/// The still for one clip, made once and kept beside it.
///
/// **Generated lazily, on first sight, not at record time.** Decoding is the
/// expensive part and the reel is the only thing that wants the result, so it
/// is paid for by whoever first looks — and paid once. It also means a clip
/// that arrived before thumbnails existed, or whose still was swept away, gets
/// one the next time it is listed rather than being stuck without.
///
/// Null when no frame could be got; the reel draws its play icon instead.
final clipThumbnailProvider =
    FutureProvider.family<File?, String>((ref, relative) async {
  final store = ref.watch(setVideoStoreProvider);
  final thumb = await store.fileFor(store.thumbnailFor(relative));
  if (await thumb.exists()) return thumb;

  final video = await store.fileFor(relative);
  if (!await video.exists()) return null;

  final made = await ref
      .watch(thumbnailerProvider)
      .write(video: video.path, target: thumb.path);
  return made && await thumb.exists() ? thumb : null;
});
