/// Work the app is holding that is not written down yet.
///
/// Two things in this app live in memory before they live in the database: the
/// live session, which is only committed on Finish, and the three editors that
/// keep their changes until Save. On a phone that is unremarkable — switching
/// away from an app does not end it. In a browser a reload is one keystroke and
/// it takes the lot, so something has to know whether there is anything to
/// lose. That is this.
///
/// **It is not a browser thing.** The register is kept on every platform and
/// means the same everywhere; only [leaveGuardSyncProvider] does anything with
/// it, and only where a browser is there to ask the question. Keeping it
/// platform-independent is what lets a test assert the arming without a
/// browser, and what stops the iOS port from re-deriving which screens hold
/// unsaved state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../util/leave_guard.dart';

/// The screens currently holding edits that Save has not taken yet.
///
/// Keyed by an opaque token rather than counted, because a count cannot survive
/// a screen that releases twice — a dispose racing a save is exactly the shape
/// that would leave the count stuck above zero and the warning armed for ever.
/// Pass the `State` object itself; it is unique and it is already to hand.
class PendingEdits extends Notifier<Set<Object>> {
  @override
  Set<Object> build() => const {};

  /// Declares that [token]'s screen has changes worth warning about.
  void hold(Object token) {
    if (!ref.mounted || state.contains(token)) return;
    state = {...state, token};
  }

  /// Declares that [token]'s screen no longer has any. Idempotent.
  ///
  /// The `ref.mounted` guard is for the release that arrives from a screen's
  /// `dispose` during a teardown that has already taken the container with it —
  /// the app shutting down, or a test ending. There is nothing left to warn
  /// about at that point, and touching `state` would throw.
  void release(Object token) {
    if (!ref.mounted || !state.contains(token)) return;
    state = {...state}..remove(token);
  }
}

final pendingEditsProvider = NotifierProvider<PendingEdits, Set<Object>>(
  PendingEdits.new,
);

/// Whether leaving right now would throw something away.
///
/// The live session counts without anyone registering it: it is already a
/// provider, and it is unsaved by construction from the moment it starts until
/// Finish writes it down.
final unsavedWorkProvider = Provider<bool>((ref) {
  return ref.watch(activeWorkoutProvider) != null ||
      ref.watch(pendingEditsProvider).isNotEmpty;
});

/// The seam the arming decision goes out through.
///
/// A provider rather than a direct call to `setLeaveGuard`, so a test can watch
/// *what the app decided* without a browser to observe it in. The real one is
/// a no-op on Android — see `leave_guard_native.dart` — but a test asserting
/// "the native build never arms it" would then pass against any implementation
/// at all, including one that armed it wrongly.
final leaveGuardProvider = Provider<void Function(bool)>(
  (ref) => setLeaveGuard,
);

/// Keeps the browser's question in step with what there is to lose.
///
/// Watch it somewhere permanent; see `main.dart`. Nothing reads its value —
/// the point is the side effect, in the same shape as `workoutShadeSyncProvider`.
///
/// A build with no [Capabilities.leaveGuard] never calls out at all, rather
/// than calling out with false: there is nothing on the other end, and the
/// register is still worth keeping there for the screens that ask it.
final leaveGuardSyncProvider = Provider<void>((ref) {
  if (!ref.watch(capabilitiesProvider).leaveGuard) return;
  ref.watch(leaveGuardProvider)(ref.watch(unsavedWorkProvider));
});

/// The editor half of [pendingEditsProvider], for a screen that holds its
/// changes until Save.
///
/// Three screens do — the routine builder, the workout builder and the exercise
/// form — and the bookkeeping is identical in all three, so it is written here
/// once. A screen calls [markEdited] from wherever it already mutates its own
/// state, and [markSaved] when the database has taken it. Leaving the screen
/// releases it either way: backing out is a decision to lose the edit, and the
/// browser must not go on asking about something the user has already walked
/// away from.
mixin TracksUnsavedEdits<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Held from [initState] rather than read in [dispose].
  ///
  /// `ref` is not usable once the element is unmounting, and the release has to
  /// happen exactly then. The notifier itself is an ordinary object and outlives
  /// the widget, so keeping it is both safe and the only thing that works.
  PendingEdits? _edits;

  @override
  void initState() {
    super.initState();
    _edits = ref.read(pendingEditsProvider.notifier);
  }

  /// This screen now holds something Save has not taken.
  void markEdited() => _edits?.hold(this);

  /// It does not any more — the database has it, or there was never anything.
  void markSaved() => _edits?.release(this);

  @override
  void dispose() {
    _edits?.release(this);
    super.dispose();
  }
}
