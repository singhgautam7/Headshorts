import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/feed/http_client.dart';
import 'package:headshorts/data/feed/refresh_service.dart';
import 'package:headshorts/data/sources/rss_source_adapter.dart';
import 'package:headshorts/data/sources/source_adapter.dart';

class WidgetRefreshResult {
  const new({required this.ok, required this.failed, required this.total});

  final int ok;
  final int failed;
  final int total;

  Map<String, int> toMap() => {'ok': ok, 'failed': failed, 'total': total};
}

/// Refreshes the given sources (every enabled one when [ids] is null) with
/// the same pool width and per-feed ceiling as [RefreshService], inside one
/// overall [deadline]. Feeds still running at the deadline count as failed
/// and write nothing afterwards. Never throws.
Future<WidgetRefreshResult> runWidgetRefresh({
  required SourceRepository sources,
  required ArticleRepository articles,
  required SourceAdapterRegistry registry,
  Set<int>? ids,
  Duration deadline = const Duration(seconds: 45),
  Future<void> Function()? prune,
}) async {
  final todo = [
    for (final s in await sources.enabled())
      if (!s.isAbandoned && (ids == null || ids.contains(s.id))) s,
  ];
  var ok = 0;
  var failed = 0;
  var expired = false;
  final queue = [...todo];

  Future<void> worker() async {
    while (queue.isNotEmpty && !expired) {
      final source = queue.removeAt(0);
      try {
        final result = await registry
            .resolve(source.type)
            .fetch(source.ref)
            .timeout(
              RefreshService.perFeedTimeout,
              onTimeout: () => const FetchResult.failed('Timed out.'),
            );
        if (expired) return;
        switch (result) {
          case FetchFresh(
            articles: final items,
            :final etag,
            :final lastModified,
          ):
            // Items first, validators second, as the app's own refresh does.
            await articles.upsert(source.id, items);
            await sources.recordSuccess(
              source.id,
              etag: etag,
              lastModified: lastModified,
            );
            ok++;
          case FetchUnchanged():
            await sources.recordSuccess(
              source.id,
              etag: source.etag,
              lastModified: source.lastModified,
            );
            ok++;
          case FetchFailed(:final message):
            await sources.recordFailure(source.id, message);
            failed++;
        }
      } on Object catch (_) {
        if (!expired) {
          failed++;
          await sources.recordFailure(source.id, 'The feed could not be read.');
        }
      }
    }
  }

  final done = Future.wait([
    for (var i = 0; i < RefreshService.concurrency; i++) worker(),
  ]);
  try {
    await done.timeout(deadline);
  } on TimeoutException {
    expired = true;
  }
  // Whatever did not report in time failed.
  failed = todo.length - ok;
  if (!expired) await prune?.call();
  return WidgetRefreshResult(ok: ok, failed: failed, total: todo.length);
}

/// The headless entrypoint body: ask Kotlin which sources, refresh them,
/// report `{ok, failed, total}` and let the job finish. Kotlin owns the
/// engine's lifetime; this only has to answer `done`.
Future<void> runWidgetRefreshEntry() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  const channel = MethodChannel('headshorts/widget_refresh');
  var result = const WidgetRefreshResult(ok: 0, failed: 0, total: 0);
  HsDatabase? db;
  try {
    final args = await channel.invokeMapMethod<String, Object?>('ready');
    final ids = (args?['ids'] as List<Object?>?)?.cast<int>().toSet();
    db = HsDatabase();
    final dio = buildHttpClient();
    try {
      result = await runWidgetRefresh(
        sources: SourceRepository(db),
        articles: ArticleRepository(db),
        registry: SourceAdapterRegistry([RssSourceAdapter(dio)]),
        ids: ids,
        prune: db.pruneToRetention,
      );
    } finally {
      dio.close(force: true);
    }
  } on Object catch (_) {
    // Reported as zero of zero; Kotlin reads that as a failed refresh only
    // when nothing came back at all.
  } finally {
    try {
      await db?.close().timeout(const Duration(seconds: 3));
    } on Object catch (_) {}
    try {
      await channel.invokeMethod<void>('done', result.toMap());
    } on Object catch (_) {}
  }
}
