import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Whether the zone database has been loaded and `tz.local` pointed at the
/// phone's own zone.
bool _ready = false;

/// Prepares `tz.local` for anything that schedules a notification.
///
/// Both schedulers need it — the reminders and the end of a rest — and the
/// package's setup is global, so it happens once here rather than once in each.
/// Safe to call repeatedly; only the first call does anything.
///
/// A zone name the database does not know leaves `tz.local` at UTC, which would
/// fire a reminder at the wrong hour. That is worth a line in a bug report and
/// not worth a crash on launch, so it is reported and swallowed.
Future<void> ensureLocalTimeZone() async {
  if (_ready) return;
  tzdata.initializeTimeZones();
  try {
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
  } catch (e) {
    debugPrint('Could not resolve the local time zone ($e)');
  }
  _ready = true;
}
