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

/// Derives the Stats screen from read state. Nothing is stored just to be
/// counted; every number here is a query over what the reader already did.
class StatsRepository {
  const new(this._db);

  final HsDatabase _db;

  static DateTime _midnight(DateTime t) => DateTime(t.year, t.month, t.day);

  Future<StatsSummary> summarise({int windowDays = 30}) async {
    final since = _midnight(DateTime.now())
        .subtract(Duration(days: windowDays));

    final articles = await (_db.select(
      _db.articles,
    )..where((a) => a.fetchedAt.isBiggerOrEqualValue(since))).get();
    if (articles.isEmpty) return StatsSummary.empty;

    final sources = {
      for (final s in await _db.select(_db.sources).get()) s.id: s,
    };

    final perSource = <int, (int arrived, int opened)>{};
    for (final article in articles) {
      final prior = perSource[article.sourceId] ?? (0, 0);
      perSource[article.sourceId] = (
        prior.$1 + 1,
        prior.$2 + (article.readInFull ? 1 : 0),
      );
    }

    final readThrough =
        perSource.entries
            .where((e) => sources.containsKey(e.key))
            .map(
              (e) => SourceReadThrough(sources[e.key]!, e.value.$1, e.value.$2),
            )
            .toList()
          ..sort((a, b) => b.fraction.compareTo(a.fraction));

    return StatsSummary(
      arrived: articles.length,
      readInFull: articles.where((a) => a.readInFull).length,
      seenInLinger: articles.where((a) => a.readInReel && !a.readInFull).length,
      perSource: readThrough,
      minutesByDay: await _minutesByDay(),
      caughtUpDays: await _caughtUpDays(windowDays),
      windowDays: windowDays,
    );
  }

  Future<List<DayMinutes>> _minutesByDay({int days = 14}) async {
    final today = _midnight(DateTime.now());
    final since = today.subtract(Duration(days: days - 1));
    final events = await (_db.select(
      _db.readEvents,
    )..where((e) => e.at.isBiggerOrEqualValue(since))).get();

    final totals = <DateTime, double>{};
    for (final event in events) {
      final day = _midnight(event.at);
      totals[day] = (totals[day] ?? 0) + event.dwellMs / 60000;
    }

    return [
      for (var i = 0; i < days; i++)
        () {
          final day = since.add(Duration(days: i));
          return DayMinutes(day, totals[day] ?? 0);
        }(),
    ];
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
