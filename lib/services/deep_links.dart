import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

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
  if (uri.scheme != ThemeCode.scheme) return null;
  // fosslift://theme/<code> — the host is "theme", the code is the path. Some
  // senders normalise the slashes differently, so accept the code wherever it
  // lands rather than insisting on one exact shape.
  if (uri.host != 'theme') return null;
  final code = uri.pathSegments.isEmpty ? '' : uri.pathSegments.join('/');
  if (code.isEmpty) return null;
  return '/settings/theme/import?code=${Uri.encodeQueryComponent(code)}';
}

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

  @override
  void initState() {
    super.initState();
    _subscription = AppLinks().uriLinkStream.listen(
      (uri) {
        final route = routeForLink(uri);
        if (route != null && mounted) widget.router.push(route);
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
