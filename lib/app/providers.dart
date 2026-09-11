import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/stats_repository.dart';
import 'package:headshorts/data/feed/feed_discovery.dart';
import 'package:headshorts/data/feed/http_client.dart';
import 'package:headshorts/data/feed/refresh_service.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/readability/extraction_service.dart';
import 'package:headshorts/data/sources/rss_source_adapter.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/data/sources/source_catalog.dart';

/// Overridden in `main` once the store has loaded, so no screen ever has to
/// wait on preferences.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw UnimplementedError('SettingsStore must be overridden'),
);

final databaseProvider = Provider<HsDatabase>((ref) {
  final db = HsDatabase();
  ref.onDispose(db.close);
  return db;
});

final httpClientProvider = Provider<Dio>((ref) {
  final dio = buildHttpClient();
  ref.onDispose(dio.close);
  return dio;
});

final sourceRepositoryProvider = Provider<SourceRepository>(
  (ref) => SourceRepository(ref.watch(databaseProvider)),
);

final articleRepositoryProvider = Provider<ArticleRepository>(
  (ref) => ArticleRepository(ref.watch(databaseProvider)),
);

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(ref.watch(databaseProvider)),
);

/// The one place source adapters are registered. A new kind of source is a
/// new class plus a line in this list.
final adapterRegistryProvider = Provider<SourceAdapterRegistry>(
  (ref) =>
      SourceAdapterRegistry([RssSourceAdapter(ref.watch(httpClientProvider))]),
);

final refreshServiceProvider = Provider<RefreshService>(
  (ref) => RefreshService(
    database: ref.watch(databaseProvider),
    sources: ref.watch(sourceRepositoryProvider),
    articles: ref.watch(articleRepositoryProvider),
    registry: ref.watch(adapterRegistryProvider),
  ),
);

final feedDiscoveryProvider = Provider<FeedDiscovery>(
  (ref) => FeedDiscovery(ref.watch(httpClientProvider)),
);

final extractionServiceProvider = Provider<ExtractionService>(
  (ref) => ExtractionService(ref.watch(httpClientProvider)),
);

/// The bundled catalog, parsed once per launch.
///
/// Nothing in it is subscribed: it is a directory to search, not a starting
/// state. Subscribing happens in Sources, and only there.
final sourceCatalogProvider = FutureProvider<SourceCatalog>(
  (ref) => SourceCatalog.load(),
);
