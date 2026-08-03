import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../data/routine_code.dart';
import '../data/share_code.dart';
import '../theme/theme_code.dart';

/// Turns a `fosslift://` URI into an in-app route.
///
/// Kept apart from the plumbing that receives them so the mapping — the part
/// that can actually be wrong — is testable without a platform channel.
///
/// Returns null for anything unrecognised. An unknown link is ignored rather
/// than guessed at: a link is untrusted input, and navigating somewhere
/// arbitrary because a URL looked vaguely right is worse than doing nothing.
String? routeForLink(Uri uri) {
  if (uri.scheme != kShareScheme) return null;
  // fosslift://<host>/<code> — the host says what was shared, the code is the
  // path. Some senders normalise the slashes differently, so accept the code
  // wherever it lands rather than insisting on one exact shape.
  final code = uri.pathSegments.isEmpty ? '' : uri.pathSegments.join('/');
  if (code.isEmpty) return null;
  return importRoute(uri.host, code);
}

/// Where a code of [host] is confirmed — the only screens allowed to apply one.
/// Null for a host this build does not share.
String? importRoute(String host, String code) {
  final encoded = Uri.encodeQueryComponent(code);
  return switch (host) {
    ThemeCode.host => '/settings/appearance/import?code=$encoded',
    RoutineCode.host => '/routine/import?code=$encoded',
    _ => null,
  };
}

/// Whether [text] actually reads as a shared [host] — a whole theme, a whole
/// routine. Used by the scanner to ignore the Wi-Fi QR on a café wall instead
/// of yanking the user into an import screen.
bool readsAsShare(String host, String text) => switch (host) {
      ThemeCode.host => ThemeCode.decode(text) is ThemeCodeOk,
      RoutineCode.host => RoutineCode.decode(text) is RoutineCodeOk,
      _ => false,
    };

/// Listens for `fosslift://` links and routes them.
///
/// Covers both ways one arrives: the cold start, where the link launched the
/// app, and the warm case, where the app was already running — [AppLinks.uriLinkStream]
/// reports the initial link too, so a single subscription handles both without
/// racing to read it separately.
class DeepLinkListener extends StatefulWidget {
  const DeepLinkListener({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends State<DeepLinkListener> {
  Object? _subscription;

  /// The last link actually routed, across every instance of this widget.
  ///
  /// Static because the instance does not outlive the reason to remember. The
  /// app root re-keys `MaterialApp` on a palette change, which tears this down
  /// and builds a fresh one; the fresh one subscribes and `uriLinkStream`
  /// replays the link that launched the app. Without this, changing the theme
  /// after opening a shared theme drops you back on the import screen you just
  /// came from.
  static Uri? _routed;

  @override
  void initState() {
    super.initState();
    _subscription = AppLinks().uriLinkStream.listen(
      (uri) {
        if (uri == _routed) return;
        final route = routeForLink(uri);
        if (route == null || !mounted) return;
        _routed = uri;
        widget.router.push(route);
      },
      // A malformed link from the OS is not worth crashing over; the user gets
      // the app they tapped to open, just not the import.
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    (_subscription as dynamic)?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
