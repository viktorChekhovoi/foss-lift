/// Reducing a video link to the only part of it that means anything.
///
/// A YouTube URL as pasted carries a timestamp, a playlist, an index, a
/// tracking parameter and a `www.` — none of which identify the video. The id
/// does, in eleven characters, and eleven characters is a size a share code can
/// afford where a full URL is not.
///
/// Pure, and free of Flutter and drift, so the rules are testable on their own.
library;

/// The eleven-character video id in a YouTube [url], or null if there is not
/// one in there.
///
/// Handles every shape a person actually pastes: `watch?v=`, `youtu.be/`,
/// `/shorts/`, `/embed/`, with or without a scheme, `www.` or `m.`. Anything
/// else — a search results page, a link to another site, a typo — has no video
/// behind it to name, and gets null rather than a guess.
String? youTubeVideoId(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;

  // A bare "youtube.com/…" is not a URI with a host until it has a scheme.
  final uri = Uri.tryParse(
      RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(trimmed)
          ? trimmed
          : 'https://$trimmed');
  if (uri == null) return null;

  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^(www|m)\.'), '');
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  final candidate = switch (host) {
    'youtu.be' => segments.isEmpty ? null : segments.first,
    'youtube.com' || 'youtube-nocookie.com' => switch (segments) {
        // youtube.com/watch?v=… — the id is a query parameter, not a path.
        [] || ['watch'] => uri.queryParameters['v'],
        ['shorts', final id, ...] => id,
        ['embed', final id, ...] => id,
        ['v', final id, ...] => id,
        // Anything else under youtube.com — /results, /channel, /playlist —
        // is a page, not a video.
        _ => null,
      },
    _ => null,
  };

  return candidate != null && _isVideoId(candidate) ? candidate : null;
}

/// The canonical short form, which is what an import rebuilds.
String youTubeUrl(String videoId) => 'https://youtu.be/$videoId';

/// A YouTube id is exactly eleven characters of the URL-safe base64 alphabet.
/// Checked rather than assumed: `youtu.be/results` would otherwise arrive as a
/// perfectly confident, entirely wrong video.
bool _isVideoId(String s) => RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(s);
