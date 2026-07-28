# Privacy Policy for Foss Lift

**Last updated: 27 July 2026**

Foss Lift is an offline workout tracker. This policy explains what happens to
your information, and the short version is: nothing. The app has no account
system, no analytics, no advertising, and no server to send anything to.

## What we collect

**Nothing.** Foss Lift does not collect, transmit, sell, or share any personal
data or usage data. There is no developer-operated server, no account to create,
and no telemetry of any kind.

## What the app stores, and where

Everything you enter — your routines, workouts, exercises, logged sets, weights
and session history — is written to a database file in Foss Lift's own private
storage on your device. Android prevents other apps from reading it.

The only other files the app writes are the small share files described below,
which go to the same private storage and only when you ask for one.

That data is never uploaded anywhere by Foss Lift.

## Sharing a routine or a theme

Foss Lift can turn one of your routines, or a colour theme you have built, into
a short code — shown on screen, copied to your clipboard, saved as a small file
in the app's own storage, or handed to your phone's share sheet so you can send
it to someone yourself.

Three things are worth being clear about:

- **Nothing is shared unless you ask for it.** There is no background sync and
  no automatic upload. Sharing happens when you tap Share, and not otherwise.
- **Once you hand a code to another app, this policy stops applying.** If you
  choose a messaging app from the share sheet, the code travels under that app's
  rules, not ours. Foss Lift has no say in what happens next and no way to take
  it back.
- **A code contains the plan, not your training.** It carries the routine's
  shape — its workouts, exercise slots, targets and schedule — and the
  definition of any exercise it uses. It does not carry your logged sets, your
  weights, your history, your streaks or your reminder times. Somebody you send
  a routine to learns what you intend to do, never what you have done.

## Network access

The released version of Foss Lift is built **without the Android `INTERNET`
permission**, so it is technically incapable of making a network connection.

The exercise library includes demo-video links (searches on YouTube). If you tap
one, Foss Lift hands the address to your browser or YouTube app and steps out of
the way — it does not load the page itself, and it sends nothing of its own
along with the request. From that point you are visiting an ordinary website,
and what happens there is covered by that site's privacy policy, not this one.
Nothing about your training is included in the link.

Links are only ever opened when you tap one. Foss Lift never opens anything on
its own or in the background.

## Permissions the app requests

- **Notifications** (`POST_NOTIFICATIONS`) — only if you switch on a reminder
  for a routine. Reminders are alarms your device sets for itself; no
  notification passes through any server.
- **Run at startup** (`RECEIVE_BOOT_COMPLETED`) — so that reminders you have
  already scheduled survive a reboot.
- **Camera** (`CAMERA`) — for two things, and only when you ask for either. If
  you never scan a code and never film a set, the app never asks.
  - **Scanning a QR code** to import a routine or a colour theme. The image is
    examined on your device for a code and then discarded: no frame is saved,
    and nothing is recorded.
  - **Filming a set**, which does write a file. See below.

The app requests no other permissions. It does not use your location,
microphone, contacts or advertising identifier, and it does not ask for access
to your photos or to the shared storage on your device. **Recording a set
captures no audio**, which is why the microphone is not on that list.

## Videos you record

Foss Lift can film a set while you train, and keep the clip attached to the set
it was. This is the only part of the app that stores something recognisably a
person, so it is worth being precise about.

- **Recording is the only way a video gets in.** You cannot import one from your
  gallery, and the app never asks for access to your photos.
- **Clips are stored in the app's own private storage**, not in your camera roll
  or gallery. No other app can list or read them. They do not appear in your
  photo library, and nothing else on your phone is told they exist.
- **No audio is captured.** A recording is picture only.
- **The camera runs only while you are filming it**, and is released the moment
  the recording screen closes. It is never opened in the background.
- **There is no way to upload or share a clip from this app.** Routines and
  themes have a share sheet; videos deliberately do not. A clip leaves your
  phone only if you move the file yourself by some other means.
- **Deleting is yours to do, and the app never does it for you.** Nothing is
  removed on a schedule or to save space. Settings shows how much room your
  clips take and lets you delete them — all of them, or one at a time. A deleted
  clip is gone from the device and does not come back.
- **A recording stops itself** after 60 seconds (or 3 minutes, if you raise it),
  so a camera left running cannot quietly fill your phone.

## Device backups

If Android's own backup feature is enabled on your phone, the operating system
may include Foss Lift's data in the encrypted backup it makes to your Google
account. That copy is made by Android, not by Foss Lift, and it is governed by
Google's privacy policy and your own device settings. You can turn it off in
Android's system settings under Backup.

This applies to videos you have recorded as well as to your training data. If
you would rather your clips never left the device even in an encrypted backup,
turn Android's backup off.

## Third parties

Foss Lift contains no advertising SDKs, no analytics SDKs, and no crash
reporting. No third party receives any information about you through this app.

## Children

Foss Lift collects no data from anyone, including children.

## Deleting your data

Uninstalling Foss Lift, or clearing its storage in Android's app settings,
permanently deletes everything the app has stored. There is no copy held
anywhere else for us to delete, because there is nowhere else.

## Open source

Foss Lift is free and open-source software. You do not have to take any of the
above on trust — the complete source is published at
<https://github.com/viktorChekhovoi/foss-lift> and can be read and built by
anyone.

## Changes to this policy

If a future version of Foss Lift ever changes what it does with your data, this
policy will be updated before that version is released, and the date at the top
will change.

## Contact

Questions about this policy: **birdie.software.studios@gmail.com**
