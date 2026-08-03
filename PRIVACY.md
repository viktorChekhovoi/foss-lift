# Privacy Policy for Foss Lift

**Last updated: 27 July 2026**

Foss Lift is an offline workout tracker.

## What we collect

**Nothing.** Foss Lift does not collect, transmit, sell, or share any personal
data or usage data. 

## What the app stores, and where

Everything you log or save through the app (routines, workouts, exercises, logged sets, weights
and session history) is written to a database file in Foss Lift's private
storage on your device. Android prevents other apps from reading it.

That data is never uploaded anywhere by Foss Lift.

**In a browser**, the same database is held by the browser itself, in the storage
set aside for the page's address. No other site can read it and it is still never
uploaded — but it is browser data, so clearing your browsing data deletes it, and
a private window starts empty and keeps nothing. The Android app is the one to
use if you want your training history to persist.

## Sharing a routine or a theme

Foss Lift can turn one of your routines, or a color theme you have built, into
a short code; that code can be shown on screen, copied to your clipboard, or handed to your phone's share flow so you can send it to someone yourself.

- **Nothing is shared until the user initiates it.** 
- **A code does not contain personal data.** It includes workout routine details or color theme configuration. No workout history or recorded video clips are shared.


## Network access

Foss Lift is built **without the Android `INTERNET` permission**, so it is incapable of making a network connection.

The exercise library includes demo-video links. If you tap one, Foss Lift hands the address to your browser or YouTube app. 
From that point you are visiting an ordinary website, and what happens there is covered by that site's privacy policy.

Links are only ever opened when you tap one. Foss Lift never opens anything on
its own or in the background.

## Permissions the app requests

- **Notifications** (`POST_NOTIFICATIONS`) -- used to send workout reminders and display the current workout in the notification bar.
- **Vibration** (`VIBRATE`) -- vibrate the phone when a rest timer is up.
- **Run at startup** (`RECEIVE_BOOT_COMPLETED`) -- keeps reminders working after a phone restarts.
- **Run in foreground** (`FOREGROUND_SERVICE`) -- prevents the system from shutting down the app when you exit to the home screen or switch to another app. Required in order to keep the active workout running.
- **Camera** (`CAMERA`) -- only used for:
  - **Scanning a QR code** to import a routine or a color theme. The image is
    examined on your device and immediately discarded.
  - **Filming a set**, which creates a file in private storage. See below for more information on set videos.

### Videos you record

Through Foss Lift, you can film a set while you train, and keep the clip attached 
to its set. 

- **Recording is handled within the app** Foss Lift never accesses your gallery or other photos.
- **Clips are stored in the app's private storage.** No other app can list or read them. 
- **No audio is captured.** A recording is picture only.
- **There is no way to upload or share a clip from this app.** Routines and
  themes have a share sheet; videos deliberately do not. A clip leaves your
  phone only if you move the file yourself.

## Device backups

If Android's backup feature is enabled on your phone, the operating system
may include Foss Lift's data in the encrypted backup it makes to your Google
account. That copy is made by Android, not by Foss Lift, and it is governed by
Google's privacy policy and your device settings. You can turn it off in
Android's system settings under Backup.

This applies to videos you have recorded as well as to your training data. If
you would rather your clips never left the device even in an encrypted backup,
turn Android's backup off.

## Third parties

Foss Lift contains no advertising SDKs, no analytics SDKs, and no crash
reporting. No third party receives any information about you through this app.

## Deleting your data

Uninstalling Foss Lift, or clearing its storage in Android's app settings,
permanently deletes everything the app has stored. There is no copy held
anywhere else for us to delete, because there is nowhere else.

## Open source

Foss Lift is free and open-source software. The complete source is published at
<https://github.com/viktorChekhovoi/foss-lift> and can be read and built by
anyone.

## Changes to this policy

If a future version of Foss Lift ever changes what it does with your data, this
policy will be updated before that version is released, and the date at the top
will change.

## Contact

Questions about this policy: **birdie.software.studios@gmail.com**
