# Privacy Policy for Foss Lift

Last updated: 28 October 2026

Foss Lift is a workout tracker. Training works offline without an account. There are no advertising, analytics, or crash-reporting SDKs.

## Local training data

Routines, exercises, notes, settings and completed workouts are stored in a SQLite database in the app's private storage on Android and iOS. In the web app, the browser stores that database for the app's origin. Clearing app or site storage deletes the local copy. A private browser window may discard it when closed.

The native Android and iOS apps do not upload training data to our server. The Android release has no Internet permission. Browser cloud backups are optional and are described below.

## Optional browser cloud backup

On the web, Profile → Cloud backup lets you request an email sign-in link and explicitly save or restore a backup. Signing in does not automatically upload training data. A backup contains routines, exercises, completed history, preferences, custom themes and bars. Video files and unfinished workouts are not uploaded. The service keeps one current backup, up to 1 MB, per account.

If you use this feature, the server stores your email address, the backup you choose to save, timestamps, and cryptographic hashes of login and session tokens. Login links expire after 15 minutes and work in the browser that requested them. Sessions expire after 30 days. Credentials use secure HttpOnly cookies rather than browser localStorage. Temporary rate-limit records contain hashes of email addresses and IP addresses; they expire after their request window and are removed during subsequent sign-in cleanup.

Cloudflare hosts the web app, API and D1 database. Resend delivers requested login emails when email delivery is configured. These providers process the information needed to provide those services, including ordinary network metadata. We do not sell training data or use it for advertising. Email links and backup content are not written to application logs.

Backups travel over HTTPS. They are not end-to-end encrypted: the service operator and infrastructure provider can access the stored copy. If you do not want a server copy, keep using local storage and file backups without signing in.

## Deleting server data

Profile → Cloud backup → Delete account removes the active server backup and account, invalidates all sessions, and removes outstanding login links. Local training data stays on the device. Deleting local app data or uninstalling does not delete a server account. Infrastructure recovery backups may retain deleted records until the provider's backup retention expires.

## Local file backups

On Android and iOS, Profile → Backup & restore creates a file containing your training database and, if selected, recorded clips. The file is created locally and handed to the system share sheet. You choose where it goes; a selected messaging or cloud-storage app has its own privacy policy. The file is not encrypted. Restoring a file replaces local data only after confirmation.

## Sharing and external links

Routine and theme codes are shared only when you choose to display, copy or send them. A routine code contains a training prescription, not completed history, personal exercise notes, or videos. Text you write into routine names and descriptions travels with the prescription.

Exercise demonstration links open your browser or YouTube app only when tapped. Bug reports open a draft in your mail app. Those external services operate under their own policies. Loading the web app's own engine, fonts and database assets does not require third-party font or rendering CDNs.

## Camera, video and device permissions

The camera is used to scan routine/theme QR codes or record a set when you ask. Scanning examines frames locally. Set videos are silent, are stored in app-private support storage, and do not access your photo library. The app does not request microphone access for recording.

On Android, notification permission supports workout reminders and live workout controls. Vibration announces a rest ending; boot handling restores scheduled reminders; a foreground service keeps an active workout running. iOS does not advertise those Android-specific background controls. Browser builds do not offer camera scanning or set-video recording.

Your operating system may include app data and clips in device backups according to your Apple or Google account settings. Those backups are made by the operating system, not by the Foss Lift cloud-backup service.

## Deleting local data

Use the app's reset action, clear its storage, or uninstall the native app to remove local training data. In a browser, clear the site's storage. Device backups and any files you exported are separate copies and must be managed where you saved them.

## Source and contact

Foss Lift's source is available in the [public repository](https://github.com/viktorChekhovoi/foss-lift) under AGPL-3.0-or-later.

Questions about this policy: birdie.software.studios@gmail.com.

This policy will be updated before a release changes how the app handles your data.
