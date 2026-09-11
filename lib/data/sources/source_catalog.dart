import 'package:flutter/services.dart' show rootBundle;
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/data/sources/opml.dart';

/// One publisher in the bundled catalog.
class CatalogSource {
  const new({
    required this.title,
    required this.feedUrl,
    required this.category,
    required this.accent,
    this.siteUrl,
  });

  final String title;
  final String feedUrl;
  final String category;
  final String? siteUrl;
  final SourceAccent accent;

  /// What search matches against: the publisher's name and its category.
  String get searchKey => '$title $category'.toLowerCase();
}

/// The ~45 feeds that ship with the app, read once from an OPML asset.
///
/// Deliberately a bundled file rather than a Dart list: the format is the one
/// the app already imports and exports, so a curated set is edited the same
/// way a reader's own subscriptions are, and the parser is exercised by the
/// app's own data on every launch.
///
/// Nothing here is subscribed automatically. The catalog is a directory to
/// search, not a starting state.
class SourceCatalog {
  const new(this.sources);

  factory parse(String opml) => SourceCatalog([
    for (final entry in Opml.parse(opml))
      CatalogSource(
        title: entry.title,
        feedUrl: entry.feedUrl,
        category: entry.category,
        siteUrl: entry.siteUrl,
        // The design board's own accents are carried in the file; anything
        // without one gets the same deterministic tone the app would derive.
        accent: entry.accent ?? SourceAccent.fromKey(entry.feedUrl),
      ),
  ]);

  static const assetPath = 'assets/feeds/starter_feeds.opml';

  final List<CatalogSource> sources;

  static const empty = SourceCatalog([]);

  /// Parses the bundled asset. Called once and cached by the provider.
  static Future<SourceCatalog> load() async =>
      SourceCatalog.parse(await rootBundle.loadString(assetPath));

  /// The categories present, in the order they appear in the file.
  List<String> get categories =>
      sources.map((s) => s.category).toSet().toList();

  /// Case-insensitive search over name and category.
  ///
  /// An empty query returns everything: the catalog is browsable, and typing
  /// only narrows it.
  List<CatalogSource> search(String query) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return sources;

    return sources
        .where((s) => terms.every((term) => s.searchKey.contains(term)))
        .toList();
  }

  /// Search results grouped for display, in catalog order.
  Map<String, List<CatalogSource>> grouped(String query) {
    final grouped = <String, List<CatalogSource>>{};
    for (final source in search(query)) {
      grouped.putIfAbsent(source.category, () => []).add(source);
    }
    return grouped;
  }
}
