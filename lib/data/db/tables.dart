import 'package:drift/drift.dart';

/// The kind of adapter that services a source. Adding a new kind means adding
/// a value here plus one `SourceAdapter` implementation — nothing else.
enum SourceType { rss }

/// How an article was seen. Kept as events so Stats can answer questions the
/// article row alone cannot ("how long", "how often").
enum ReadMode { linger, full }

@DataClassName('SourceRow')
class Sources extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get siteUrl => text().nullable()();
  TextColumn get feedUrl => text().unique()();
  TextColumn get category => text()();

  /// The two tones of the source accent — light-on-black and deep-on-paper.
  IntColumn get accentDark => integer()();
  IntColumn get accentLight => integer()();

  TextColumn get type => textEnum<SourceType>()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Conditional-GET validators, so a refresh usually costs a 304.
  TextColumn get etag => text().nullable()();
  TextColumn get lastModified => text().nullable()();

  DateTimeColumn get lastFetchedAt => dateTime().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  /// A feed that stops responding is stated in words on its own screen, never
  /// as a badge. These two columns are what that screen reads.
  DateTimeColumn get failingSince => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
}

@DataClassName('ArticleRow')
class Articles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sourceId =>
      integer().references(Sources, #id, onDelete: KeyAction.cascade)();

  /// Feed-provided identity, falling back to the link when absent.
  TextColumn get guid => text()();
  TextColumn get title => text()();
  TextColumn get summary => text().nullable()();
  TextColumn get contentSnippet => text().nullable()();

  /// Populated only when a full-content feed or on-device extraction provides
  /// it. Null means the Reader must extract, or degrade to the publisher.
  TextColumn get fullContentHtml => text().nullable()();

  TextColumn get link => text()();
  TextColumn get author => text().nullable()();
  DateTimeColumn get publishedAt => dateTime()();
  TextColumn get imageUrl => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();

  /// Silent read state. Never surfaced as a count.
  BoolColumn get readInReel => boolean().withDefault(const Constant(false))();
  BoolColumn get readInFull => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sourceId, guid},
  ];
}

@DataClassName('ReadEventRow')
class ReadEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get articleId =>
      integer().references(Articles, #id, onDelete: KeyAction.cascade)();
  TextColumn get mode => textEnum<ReadMode>()();
  DateTimeColumn get at => dateTime().withDefault(currentDateAndTime)();
  IntColumn get dwellMs => integer().withDefault(const Constant(0))();
}

/// One row per day the reader reached the end of Today. Shown as a grid of
/// filled and empty squares — no streak count, no "keep it going".
@DataClassName('CaughtUpRow')
class CaughtUpDays extends Table {
  DateTimeColumn get day => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {day};
}
