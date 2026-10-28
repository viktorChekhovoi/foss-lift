# Privacy Policy for Foss Lift

Last updated: 28 October 2026

Foss Lift is an offline workout tracker. There are no Foss Lift accounts, server backups, advertising, analytics, or crash-reporting SDKs. The app does not upload your training data.

## Local training data

Routines, exercises, notes, settings and completed workouts are stored in a SQLite database in the app's private storage on Android and iOS. In the web app, the browser stores that database for the app's origin. Clearing app or site storage deletes the local copy. A private browser window may discard it when closed.

The Android release has no Internet permission. The iOS and web apps have no account or backup API. Training works locally without signing in.

## Local file backups

On Android and iOS, Profile → Backup & restore creates a file containing your training database and, if selected, recorded clips. The file is created locally and handed to the system share sheet. You choose where it goes; a selected messaging or cloud-storage app has its own privacy policy. The file is not encrypted. Restoring a file replaces local data only after confirmation.

## Sharing and external links

Routine and theme codes are shared only when you choose to display, copy or send them. A routine code contains a training prescription, not completed history, personal exercise notes, or videos. Text you write into routine names and descriptions travels with the prescription.

Exercise demonstration links open your browser or YouTube app only when tapped. Bug reports open a draft in your mail app. Those external services operate under their own policies.

## Web hosting

Cloudflare Pages hosts the static web app. Loading the page downloads its engine, fonts and database assets from the same origin. Cloudflare receives the ordinary network metadata needed to serve those files, such as the requesting IP address and file URL. Your routines, training history, notes and local database are not uploaded with those requests. The running app does not fetch third-party font or rendering CDNs.

## Camera, video and device permissions

The camera is used to scan routine/theme QR codes or record a set when you ask. Scanning examines frames locally. Set videos are silent, are stored in app-private support storage, and do not access your photo library. The app does not request microphone access for recording.

On Android, notification permission supports workout reminders and live workout controls. Vibration announces a rest ending; boot handling restores scheduled reminders; a foreground service keeps an active workout running. iOS does not advertise those Android-specific background controls. Browser builds do not offer camera scanning or set-video recording.

Your operating system may include app data and clips in device backups according to your Apple or Google account settings. These backups are made by the operating system and managed through its account settings.

## Deleting local data

Use the app's reset action, clear its storage, or uninstall the native app to remove local training data. In a browser, clear the site's storage. Device backups and any files you exported are separate copies and must be managed where you saved them.

## Source and contact

Foss Lift's source is available in the [public repository](https://github.com/viktorChekhovoi/foss-lift) under AGPL-3.0-or-later.

Questions about this policy: birdie.software.studios@gmail.com.

This policy will be updated before a release changes how the app handles your data.
