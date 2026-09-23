import 'package:drift/drift.dart';

/// The kind of adapter that services a source. Adding a new kind means adding
/// a value here plus one `SourceAdapter` implementation — nothing else.
enum SourceType { rss }

/// How an article was met. Kept as events so Stats can answer questions the
/// article row alone cannot ("how long", "how often").
///
/// These are two different things, not two degrees of the same thing: seeing a
/// card in Linger is not reading the article.
enum ReadMode { linger, full }

@DataClassName('SourceRow')
class Sources extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get siteUrl => text().nullable()();
  TextColumn get feedUrl => text().unique()();
  TextColumn get category => text()();

  /// BCP-47 language tag of what this source publishes — 'en', 'hi', 'ta'.
  /// A label, like the category: it filters, it never changes what is fetched.
  TextColumn get language => text().withDefault(const Constant('en'))();

  /// The two tones of the source accent — light-on-black and deep-on-paper.
  IntColumn get accentDark => integer()();
  IntColumn get accentLight => integer()();

  TextColumn get type => textEnum<SourceType>()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Kept out of the merged Latest list, while still appearing under its own
  /// category. For a firehose the reader wants, but not in with everything
  /// else.
  BoolColumn get mutedInLatest =>
      boolean().withDefault(const Constant(false))();

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

  /// The link reduced to the story's identity — tracking parameters stripped,
  /// aggregator redirects unwrapped. Two feeds carrying the same article agree
  /// on this, which is what makes cross-feed dedup and shared read state work.
  TextColumn get canonicalUrl => text().withDefault(const Constant(''))();

  /// A loose fingerprint of the headline, for the same story filed under two
  /// slightly different titles. Empty when the title is too short to be sure.
  TextColumn get titleKey => text().withDefault(const Constant(''))();
  TextColumn get author => text().nullable()();
  DateTimeColumn get publishedAt => dateTime()();
  TextColumn get imageUrl => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();

  /// The card settled as the active card in Linger. Set there and nowhere
  /// else: it keeps an item from coming back round in Linger, and has no
  /// effect on Today at all.
  BoolColumn get seenInLinger => boolean().withDefault(const Constant(false))();

  /// The reader opened the full article, from Today or from Linger. The only
  /// thing that counts as having read something.
  BoolColumn get readFull => boolean().withDefault(const Constant(false))();

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

/// An article the reader kept.
///
/// A **snapshot**, not a pointer. Everything needed to render the article is
/// copied in at save time, because the cache it came from is pruned to the
/// newest 200 per source and to 90 days, and a bookmark must outlive both.
/// Nothing here references `articles`, so no cascade or prune can reach it.
@DataClassName('BookmarkRow')
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The row it was saved from, while that row still exists. Deliberately not
  /// a foreign key: a cascade from `sources` would take the bookmark with it.
  IntColumn get articleId => integer().nullable()();

  TextColumn get link => text().unique()();
  TextColumn get canonicalUrl => text().withDefault(const Constant(''))();
  TextColumn get title => text()();
  TextColumn get summary => text().nullable()();

  /// The extracted body, so a saved article opens offline and unchanged.
  TextColumn get contentHtml => text().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get imageUrl => text().nullable()();

  TextColumn get sourceTitle => text()();
  TextColumn get language => text().withDefault(const Constant('en'))();
  IntColumn get accentDark => integer()();
  IntColumn get accentLight => integer()();

  DateTimeColumn get publishedAt => dateTime()();
  DateTimeColumn get savedAt => dateTime().withDefault(currentDateAndTime)();
}
