import 'package:intl/intl.dart';

/// "2 hours ago" — the app's only time format in lists.
///
/// Deliberately coarse: an exact minute count invites checking back.
String relativeTime(DateTime when, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(when);

  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inMinutes < 60) return _plural(elapsed.inMinutes, 'minute');
  if (elapsed.inHours < 24) return _plural(elapsed.inHours, 'hour');
  if (elapsed.inDays < 7) return _plural(elapsed.inDays, 'day');
  return DateFormat('d MMMM').format(when);
}

String _plural(int count, String unit) =>
    '$count $unit${count == 1 ? '' : 's'} ago';

/// "8 September, 4:12 am" — the Reader's own dateline.
String articleDateline(DateTime when) =>
    DateFormat('d MMMM, h:mm a')
        .format(when)
        .replaceAll('AM', 'am')
        .replaceAll('PM', 'pm');

/// "9:38" — the wall clock beside "updated".
String clockTime(DateTime when) => DateFormat('H:mm').format(when);
