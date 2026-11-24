import 'package:drift/drift.dart';
import 'package:headshorts/data/db/database.dart';

/// The reading mirror. Counts, not scores.
class StatsSummary {
  const new({
    required this.arrived,
    required this.readInFull,
    required this.seenInLinger,
    required this.perSource,
    required this.minutesByDay,
    required this.caughtUpDays,
    required this.windowDays,
  });

  static const empty = StatsSummary(
    arrived: 0,
    readInFull: 0,
    seenInLinger: 0,
    perSource: [],
    minutesByDay: [],
    caughtUpDays: {},
    windowDays: 30,
  );

  final int arrived;
  final int readInFull;

  /// Seen in Linger but not opened.
  final int seenInLinger;
  final List<SourceReadThrough> perSource;

  /// One entry per day for the last fortnight, oldest first.
  final List<DayMinutes> minutesByDay;

  /// The days the reader reached the end of Today.
  final Set<DateTime> caughtUpDays;
  final int windowDays;

  int get passedOver => (arrived - readInFull - seenInLinger).clamp(0, arrived);

  double get averageMinutesPerDay => minutesByDay.isEmpty
      ? 0
      : minutesByDay.map((d) => d.minutes).reduce((a, b) => a + b) /
            minutesByDay.length;

  /// Sources the reader has essentially stopped opening — the pruning list.
  List<SourceReadThrough> get neverOpened =>
      perSource.where((s) => s.fraction < 0.05).toList();
}

class SourceReadThrough {
  const new(this.source, this.arrived, this.opened);

  final SourceRow source;
  final int arrived;
  final int opened;

  double get fraction => arrived == 0 ? 0 : opened / arrived;
}

class DayMinutes {
  const new(this.day, this.minutes);

  final DateTime day;
  final double minutes;
}

/// Minutes read on each day of this week, Monday first. A measure, not a
/// target: nothing here compares one day, or one week, with another.
class WeekReading {
  const new(this.minutes);

  final List<double> minutes;

  int get totalMinutes => minutes.fold<double>(0, (a, b) => a + b).round();
}

/// Derives the Stats screen from read state. Nothing is stored just to be
/// counted; every number here is a query over what the reader already did.
class StatsRepository {
  const new(this._db);

  final HsDatabase _db;

  static DateTime _midnight(DateTime t) => DateTime(t.year, t.month, t.day);

  Future<StatsSummary> summarise({int windowDays = 30}) async {
    final since = _midnight(DateTime.now())
        .subtract(Duration(days: windowDays));

    // One grouped scan: no article row (and so no body) leaves SQLite.
    final counts = await _db
        .customSelect(
          'SELECT source_id, COUNT(*) AS arrived, '
          'SUM(read_full) AS opened, '
          'SUM(seen_in_linger AND NOT read_full) AS seen '
          'FROM articles WHERE fetched_at >= ? GROUP BY source_id',
          variables: [Variable.withDateTime(since)],
          readsFrom: {_db.articles},
        )
        .get();
    if (counts.isEmpty) return StatsSummary.empty;

    final sources = {
      for (final s in await _db.select(_db.sources).get()) s.id: s,
    };

    var arrived = 0;
    var opened = 0;
    var seen = 0;
    final readThrough = <SourceReadThrough>[];
    for (final row in counts) {
      final n = row.read<int>('arrived');
      final o = row.read<int?>('opened') ?? 0;
      arrived += n;
      opened += o;
      seen += row.read<int?>('seen') ?? 0;
      final source = sources[row.read<int>('source_id')];
      if (source != null) readThrough.add(SourceReadThrough(source, n, o));
    }
    readThrough.sort((a, b) => b.fraction.compareTo(a.fraction));

    return StatsSummary(
      arrived: arrived,
      readInFull: opened,
      seenInLinger: seen,
      perSource: readThrough,
      minutesByDay: await _minutesByDay(),
      caughtUpDays: await _caughtUpDays(windowDays),
      windowDays: windowDays,
    );
  }

  /// Dwell milliseconds per local calendar day since [since], grouped in SQL.
  Selectable<QueryRow> _dwellByDay(DateTime since) => _db.customSelect(
    "SELECT strftime('%Y-%m-%d', at, 'unixepoch', 'localtime') AS day, "
    'SUM(dwell_ms) AS ms FROM read_events WHERE at >= ? GROUP BY day',
    variables: [Variable.withDateTime(since)],
    readsFrom: {_db.readEvents},
  );

  static Map<DateTime, int> _byDay(List<QueryRow> rows) => {
    for (final r in rows)
      DateTime.parse(r.read<String>('day')): r.read<int?>('ms') ?? 0,
  };

  Future<List<DayMinutes>> _minutesByDay({int days = 14}) async {
    final today = _midnight(DateTime.now());
    final since = today.subtract(Duration(days: days - 1));
    final totals = _byDay(await _dwellByDay(since).get());
    return [
      for (var i = 0; i < days; i++)
        () {
          final day = DateTime(since.year, since.month, since.day + i);
          return DayMinutes(day, (totals[day] ?? 0) / 60000);
        }(),
    ];
  }

  /// Reading this week, Monday to Sunday, live: re-emits when an event lands.
  Stream<WeekReading> watchWeek() {
    final today = _midnight(DateTime.now());
    final start = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    return _dwellByDay(start).watch().map((rows) {
      final totals = _byDay(rows);
      return WeekReading([
        for (var i = 0; i < 7; i++)
          (totals[DateTime(start.year, start.month, start.day + i)] ?? 0) /
              60000,
      ]);
    });
  }

  Future<Set<DateTime>> _caughtUpDays(int windowDays) async {
    final since = _midnight(DateTime.now())
        .subtract(Duration(days: windowDays));
    final rows = await (_db.select(
      _db.caughtUpDays,
    )..where((d) => d.day.isBiggerOrEqualValue(since))).get();
    return rows.map((r) => _midnight(r.day)).toSet();
  }

  /// Records that the reader reached the end of Today. Idempotent per day.
  Future<void> markCaughtUpToday() => _db
      .into(_db.caughtUpDays)
      .insert(
        CaughtUpDaysCompanion.insert(day: _midnight(DateTime.now())),
        mode: InsertMode.insertOrIgnore,
      );
}
