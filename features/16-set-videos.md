# Set videos

Film a set, and keep the clip attached to the set it was. Form is the thing a
number cannot tell you, and a rep filmed six weeks ago is the only honest answer
to "is my depth getting worse as the weight goes up".

Everything stays on the phone. This is a camera feature in an app with no
network, and it stays that way.

## What it does

- Records **one clip per set**, from the live workout board, against the set in
  front of you.
- Marks a set that carries a clip so it can be found again.
- **Plays one back full screen**, looping, at half or quarter speed.
- Lists **every clip of one movement** in date order — the same lift over months.
- Shows what the clips cost, and offers to reclaim it.

## How to use it

- **Film a set:** during a workout, tap the camera on the set's row, then the
  shutter. It stops itself at the cap, or when you tap stop.
- **Re-film or delete:** tap the camera again on a set that already has a clip.
- **Watch one back:** Library → the exercise → **N clips**, which is every clip
  of that movement in date order. Or from a session: History → the session →
  tap an exercise marked with a play symbol.
- **See the cost:** Profile → Settings → **Set videos**. Quality, the longest a
  clip may run, and how much space they are taking.

## Behaviour & edge cases

- **Recording is the only way a clip gets in.** Nothing is imported from the
  gallery: that would mean read access to shared storage, its own permission and
  its own privacy paragraph, for a path nobody asked for.
- **No audio, ever** (`enableAudio: false`). A gym is full of other people's
  conversations, the track is worth nothing for checking bar path, and leaving
  it off avoids the microphone permission prompt on both platforms.
- **The camera is opened only while filming**, and released the moment the
  recording screen closes. It is never held open in the background.
- **Recording stops itself.** 60 seconds by default, 3 minutes if asked for. The
  failure mode that fills a phone is a recording nobody stopped — you rack the
  bar, walk off, and the app films the ceiling. The last five seconds count
  down, so the stop is never a surprise.
- **720p by default, 480p on request. 1080p is not offered** — roughly two and a
  half times the bytes for a judgement 720p already answers.
- **Warm-ups cannot be filmed.** They are suggestions that are never saved, so
  there is no logged set for a clip to belong to. The column is still reserved
  on those rows, so the two sections line up.
- **A clip filmed mid-session is a file plus a path in memory.** The live
  workout does not touch the database until Finish, and that does not change for
  this. The path is written alongside the set when the session is saved.
- **Abandoning a workout takes its clips with it.** Nothing was written, so
  nothing points at those files, and an app quietly hoarding footage from a
  session somebody chose to bin would be indefensible.
- **A clip on a set that was never logged goes too**, at Finish — the set is not
  saved, so nothing would ever point at it.
- **Deleting a clip leaves the set alone.** A bad take is not a set that did not
  happen.
- **Re-filming replaces**, and the take it replaces is deleted then and there
  rather than left for the sweep.

## Playing one back

- **Full screen, on black**, with play/pause, a scrubber you can drag, and a
  loop that is **on by default** — a single rep replays without anybody fishing
  for the scrubber.
- **Slow motion at 0.5× and 0.25×**, on a cycling control. Nothing above 1×:
  this is for inspecting a rep, not skipping one. A sticking point goes past in
  an instant at full speed and is plain at a quarter.
- **Frame-by-frame stepping is out of scope**, deliberately. Landing on an exact
  frame means seeking past the nearest keyframe and decoding forward, which the
  player cannot be relied on to do — a step control that sometimes lands a
  second away from where you dragged is worse than no step control. Revisit it
  if the underlying player gains an exact-seek option.
- **A clip whose file has gone says so** rather than sitting at nought seconds.
  A row can outlive its file if one is removed by hand.
- **Deleting from the player** clears the row first, then the file — the same
  ordering as everywhere else.

## Finding one again

- **The exercise's own reel** is the view that makes the feature worth having: a
  flat list of every clip of that movement, newest first, each labelled with the
  set it came from — `12 Mar · set 3 · 100 kg × 5`. Your squat over months, in
  one place.
- **The button appears only once there is something to watch.** An empty reel is
  a button that teaches you the feature exists by disappointing you.
- **The session recap** marks a filmed exercise with a play symbol and a
  "N filmed" count. With more than one filmed set of the same movement the
  choice is offered rather than guessed at.
- **The label reads identically in both places.** One implementation
  (`clipLabelOf`), two callers — the same clip must not appear to be two
  different things.

## Storage — the policy, stated

- **Nothing is ever deleted automatically.** Every retention rule — keep the
  last N, drop anything older than X, evict oldest to fit a budget — deletes the
  oldest clip first, and the oldest clip is the one the feature exists for. It
  would optimise the cost by throwing away the point. Nothing else in this app
  deletes user data on its own, and video is the least recoverable thing it
  holds.
- **The caps do the work instead.** One clip cannot be large, so the library
  cannot grow surprisingly fast.
- **What is spent is visible**, in Settings, with a way to reclaim it.
- **Clips live in app-private storage** — `getApplicationSupportDirectory()`, a
  `set_videos/` subfolder — never the shared gallery, never anywhere another app
  can enumerate them, and never uploaded. There is no share sheet for a clip.
- **Only relative paths are stored** (`set_videos/<id>.mp4`), joined onto a
  freshly resolved directory every time. The iOS container path carries a UUID
  that changes on reinstall and on restore, so an absolute path works on Android
  and silently dangles on iOS.
- **The filename is a generated id** — not a timestamp, which collides, and not
  the exercise name, which would leak what somebody trains to anything that can
  list the directory.

## Never a dead reference

The failure to design against is a row pointing at a file that is gone, so every
ordering is chosen to leak a file instead:

- the file is written first, and the row that names it only at Finish;
- deleting goes row first, then file;
- **a sweep on launch** removes any file in `set_videos/` that no row points at.

The sweep leaves files younger than `kOrphanGrace` (24 hours) alone. Without
that guard it would delete the clip of the set being filmed right now, which has
no row yet by design.

There is **no way to delete a session** in the app today, so "deleting a session
removes its clips" has no path to travel. When one exists, the rows go with the
session by foreign-key cascade and the files become orphans the sweep collects.

## Where it lives

- Storage, naming and the sweep: `lib/services/set_video_store.dart`.
- The camera, behind an interface so the rules can be tested without one:
  `lib/services/set_video_recorder.dart`.
- Recording screen: `lib/screens/set_video_screen.dart`.
- Playback: `lib/screens/clip_player_screen.dart`; the reel:
  `exercise_clips_screen.dart`; the label and the speeds: `util/clip_label.dart`.
- Quality, cap and reclaim: `lib/screens/video_settings_screen.dart`.
- The path on a live set: `SetEntry.videoPath` in
  `lib/state/active_workout.dart`; on a saved one, `SessionSets.videoPath`.

## Related issues

- [#32 Record a set on video](https://github.com/viktorChekhovoi/foss-lift/issues/32)
