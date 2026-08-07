/// The leave guard in a browser: one `beforeunload` listener, added while there
/// is unsaved work and removed the moment there is not.
///
/// Reached through `leave_guard.dart` — never imported directly.
///
/// ## What the browser will and will not do
///
/// **The wording is not ours.** Every current browser ignores whatever string a
/// page supplies and shows its own generic "Leave site? Changes you made may
/// not be saved." That is a deliberate anti-phishing measure and there is no
/// way around it, so nothing here tries to write copy — the app's own text has
/// to carry the explanation *before* this point, not inside the dialog.
///
/// **The listener has to be absent, not inert.** A registered `beforeunload`
/// listener disqualifies the page from the back/forward cache in Chrome and
/// Safari even when it never calls `preventDefault`, which makes navigating
/// away and back measurably slower for no reason. So the guard adds and removes
/// the listener rather than keeping one around behind a flag.
///
/// **A page nobody has touched cannot object.** Browsers require prior user
/// interaction ("sticky activation") before they will honour the dialog, and
/// silently skip it otherwise. This is not a problem in practice: everything
/// that arms the guard — starting a workout, typing in an editor — is itself
/// the interaction that satisfies it.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The listener while it is registered, and the record of whether it is.
///
/// Held as the converted [JSFunction] rather than the Dart closure because
/// `removeEventListener` matches on JavaScript identity: converting the same
/// Dart function to JS twice yields two different objects, and removing the
/// second would leave the first attached for the life of the page.
web.EventListener? _listener;

/// Arms or disarms the browser's confirmation on leaving the page.
///
/// Idempotent, and cheap to call on every rebuild — the common case is that the
/// state already matches and nothing touches the DOM.
// ignore: avoid_positional_boolean_parameters
void setLeaveGuard(bool armed) {
  if (armed == (_listener != null)) return;
  if (armed) {
    final listener = ((web.Event event) {
      // `preventDefault` is the modern signal and `returnValue` is the legacy
      // one. Both are set: Safari still goes by the second, and setting both is
      // what the HTML standard itself recommends for the transition.
      event.preventDefault();
      (event as web.BeforeUnloadEvent).returnValue = '';
    }).toJS;
    web.window.addEventListener('beforeunload', listener);
    _listener = listener;
  } else {
    web.window.removeEventListener('beforeunload', _listener);
    _listener = null;
  }
}

/// Whether the listener is currently registered.
bool get leaveGuardArmed => _listener != null;
