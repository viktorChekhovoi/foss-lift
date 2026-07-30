/// Every notification this app posts shares one id space, and two of them are
/// laid down ahead of time — a routine's reminder and the end of a rest. They
/// have to be told apart, because re-laying the reminders cancels what is
/// pending and must not take the rest alarm with it.
///
/// So: reminders take a routine's own row id, which is small and positive, and
/// everything else lives above [kScheduledIdFloor].
library;

/// Ids at or above this belong to something other than a routine reminder.
const int kScheduledIdFloor = 1000000;

/// The end of a rest. One id, reused — there is only ever one rest, and a second
/// one replaces the first rather than stacking beside it.
const int kRestAlarmId = kScheduledIdFloor + 91;

/// Whether [id] is a routine reminder, and so a reminder sync's to cancel.
bool isReminderId(int id) => id < kScheduledIdFloor;
