# Privacy Policy for FossLift

**Last updated: 22 July 2026**

FossLift is an offline workout tracker. This policy explains what happens to
your information, and the short version is: nothing. The app has no account
system, no analytics, no advertising, and no server to send anything to.

## What we collect

**Nothing.** FossLift does not collect, transmit, sell, or share any personal
data or usage data. There is no developer-operated server, no account to create,
and no telemetry of any kind.

## What the app stores, and where

Everything you enter — your routines, workouts, exercises, logged sets, weights
and session history — is written to a database file in FossLift's own private
storage on your device. Android prevents other apps from reading it.

That data is never uploaded anywhere by FossLift.

## Network access

The released version of FossLift is built **without the Android `INTERNET`
permission**, so it is technically incapable of making a network connection.

The exercise library includes demo-video links (searches on YouTube). If you tap
one, FossLift hands the address to your browser or YouTube app and steps out of
the way — it does not load the page itself, and it sends nothing of its own
along with the request. From that point you are visiting an ordinary website,
and what happens there is covered by that site's privacy policy, not this one.
Nothing about your training is included in the link.

Links are only ever opened when you tap one. FossLift never opens anything on
its own or in the background.

## Permissions the app requests

- **Notifications** (`POST_NOTIFICATIONS`) — only if you switch on a reminder
  for a routine. Reminders are alarms your device sets for itself; no
  notification passes through any server.
- **Run at startup** (`RECEIVE_BOOT_COMPLETED`) — so that reminders you have
  already scheduled survive a reboot.

The app requests no other permissions. It does not use your location, camera,
microphone, contacts, files, or advertising identifier.

## Device backups

If Android's own backup feature is enabled on your phone, the operating system
may include FossLift's data in the encrypted backup it makes to your Google
account. That copy is made by Android, not by FossLift, and it is governed by
Google's privacy policy and your own device settings. You can turn it off in
Android's system settings under Backup.

## Third parties

FossLift contains no advertising SDKs, no analytics SDKs, and no crash
reporting. No third party receives any information about you through this app.

## Children

FossLift collects no data from anyone, including children.

## Deleting your data

Uninstalling FossLift, or clearing its storage in Android's app settings,
permanently deletes everything the app has stored. There is no copy held
anywhere else for us to delete, because there is nowhere else.

## Open source

FossLift is free and open-source software. You do not have to take any of the
above on trust — the complete source is published at
<https://github.com/viktorChekhovoi/foss-lift> and can be read and built by
anyone.

## Changes to this policy

If a future version of FossLift ever changes what it does with your data, this
policy will be updated before that version is released, and the date at the top
will change.

## Contact

Questions about this policy: **birdie.software.studios@gmail.com**
