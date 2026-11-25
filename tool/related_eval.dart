// Real-data evaluation of the "Other sources on this story" matcher.
//
//   EVAL_SAMPLE=tune flutter test tool/related_eval.dart
//   EVAL_SAMPLE=held EVAL_OFFSET=3 EVAL_EN=28 flutter test tool/related_eval.dart
//
// Fetches every English and Hindi feed in the bundled catalog once (cached in
// $EVAL_CACHE, default /tmp/related_eval_cache.json; delete it to refetch),
// keeps the last 72 hours, runs the matcher on every article, and prints
// matched pairs for a deterministic sample for a person to judge by reading.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:headshorts/data/feed/http_client.dart';
import 'package:headshorts/data/sources/opml.dart';
import 'package:headshorts/features/reader/related/related_matcher.dart';

void main() {
  test('related matcher on real feeds', () async {
    HttpOverrides.global = null;
    final cachePath =
        Platform.environment['EVAL_CACHE'] ?? '/tmp/related_eval_cache.json';
    final file = File(cachePath);
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 72));

    List<Map<String, Object?>> rows;
    if (file.existsSync()) {
      rows = (jsonDecode(file.readAsStringSync()) as List)
          .cast<Map<String, Object?>>();
    } else {
      final entries = Opml.parse(
        File('assets/feeds/starter_feeds.opml').readAsStringSync(),
      ).where((e) => e.language == 'en' || e.language == 'hi').toList();
      final dio = buildHttpClient();
      rows = [];
      var next = 0;
      Future<void> worker() async {
        while (next < entries.length) {
          final i = next++;
          final e = entries[i];
          try {
            final r = await dio
                .get<String>(e.feedUrl)
                .timeout(const Duration(seconds: 20));
            if (r.statusCode != 200 || r.data == null) continue;
            for (final a in FeedParser.parse(r.data!)) {
              if (a.publishedAt.isBefore(cutoff)) continue;
              rows.add({
                'src': i,
                'source': e.title,
                'lang': e.language,
                'title': a.title,
                'summary': a.summary ?? '',
                'link': a.link,
                'at': a.publishedAt.millisecondsSinceEpoch,
              });
            }
          } on Object catch (err) {
            print('feed failed: ${e.title}: $err');
          }
        }
      }

      await Future.wait([for (var i = 0; i < 8; i++) worker()]);
      file.writeAsStringSync(jsonEncode(rows));
    }
    print('articles: ${rows.length}');

    final sample = Platform.environment['EVAL_SAMPLE'] ?? 'tune';
    final out = StringBuffer();
    for (final lang in ['en', 'hi']) {
      final cands = <RelatedCandidate>[];
      for (final r in rows.where((r) => r['lang'] == lang)) {
        cands.add(
          RelatedCandidate(
            id: cands.length + 1,
            title: r['title']! as String,
            summary: r['summary']! as String,
            sourceId: r['src']! as int,
            canonicalUrl: r['link']! as String,
            publishedAtMs: r['at']! as int,
            sourceTitle: r['source']! as String,
          ),
        );
      }
      final sw = Stopwatch()..start();
      final hits =
          <RelatedCandidate, List<({RelatedCandidate c, double score})>>{};
      for (final c in cands) {
        final m = relatedScored(RelatedInput(article: c, candidates: cands));
        if (m.isNotEmpty) hits[c] = m;
      }
      sw.stop();
      print(
        '$lang: ${cands.length} articles, ${hits.length} with matches '
        '(${(100 * hits.length / cands.length).toStringAsFixed(1)}%), '
        '${(sw.elapsedMilliseconds / cands.length).toStringAsFixed(1)} ms/article',
      );
      final list = hits.entries.toList();
      final want = lang == 'en'
          ? (int.tryParse(Platform.environment['EVAL_EN'] ?? '') ?? 24)
          : 6;
      final k = (list.length ~/ want).clamp(1, 1000);
      final off = int.tryParse(Platform.environment['EVAL_OFFSET'] ?? '') ?? 0;
      out.writeln('== $lang (k=$k, offset=$off) ==');
      for (var i = off; i < list.length && i < off + k * want; i += k) {
        final e = list[i];
        out.writeln('* [${e.key.sourceTitle}] ${e.key.title}');
        for (final m in e.value) {
          out.writeln(
            '    -> ${m.score.toStringAsFixed(2)} [${m.c.sourceTitle}] ${m.c.title}',
          );
        }
      }
    }
    File('${cachePath}_$sample.txt').writeAsStringSync(out.toString());
    print(out);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('timing with 3000 candidates', () async {
    final cachePath =
        Platform.environment['EVAL_CACHE'] ?? '/tmp/related_eval_cache.json';
    final rows = (jsonDecode(File(cachePath).readAsStringSync()) as List)
        .cast<Map<String, Object?>>()
        .where((r) => r['lang'] == 'en')
        .toList();
    final cands = [
      for (var i = 0; i < 3000; i++)
        RelatedCandidate(
          id: i + 1,
          title: rows[i % rows.length]['title']! as String,
          summary: rows[i % rows.length]['summary']! as String,
          sourceId:
              (rows[i % rows.length]['src']! as int) + (i ~/ rows.length) * 100,
          publishedAtMs: rows[i % rows.length]['at']! as int,
        ),
    ];
    final sw = Stopwatch()..start();
    await compute(
      relatedMatches,
      RelatedInput(article: cands.first, candidates: cands),
    );
    print(
      'compute(relatedMatches) over 3000 candidates: ${sw.elapsedMilliseconds} ms',
    );
  });
}
