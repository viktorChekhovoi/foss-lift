/// The leave guard on a phone: there is nothing to guard against.
///
/// Reached through `leave_guard.dart` — never imported directly.
///
/// Leaving is something a tab does. Switching away from an Android app does not
/// end it, the live session survives in memory, and the OS gives no hook to
/// object to a task being swiped away — so the honest implementation is to do
/// nothing rather than to approximate the browser's question with a dialog
/// nobody asked for.
library;

/// Does nothing. See above.
// ignore: avoid_positional_boolean_parameters
void setLeaveGuard(bool armed) {}

/// Whether the guard is currently armed. Always false here — see above.
bool get leaveGuardArmed => false;
