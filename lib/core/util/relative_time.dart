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

/// "12m", "3h", "5d", "16 Sep" — the compact form the small list uses.
///
/// Right-aligned beside a two-line headline, there is room for a stamp, not
/// for a sentence. Still coarse: no seconds, and nothing that ticks.
String shortRelativeTime(DateTime when, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(when);

  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d';
  return DateFormat('d MMM').format(when);
}

/// "Today", "Monday, 21 September" — the day heading above a run of search
/// results.
String dayHeading(DateTime when, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime(when.year, when.month, when.day);
  final start = DateTime(today.year, today.month, today.day);
  final difference = start.difference(day).inDays;

  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  if (difference < 7) return DateFormat('EEEE, d MMMM').format(when);
  return DateFormat('d MMMM y').format(when);
}
