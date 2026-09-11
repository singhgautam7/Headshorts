import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:headshorts/data/sources/source_adapter.dart';

/// Fetches RSS 1.0/2.0 and Atom over conditional GET.
///
/// This is the only adapter today. A second kind of source is a second class
/// like this one plus a line in the registry.
class RssSourceAdapter implements SourceAdapter {
  const new(this._dio);

  final Dio _dio;

  @override
  bool canHandle(SourceType type) => type == SourceType.rss;

  @override
  Future<FetchResult> fetch(SourceRef ref) async {
    try {
      final response = await _dio.get<String>(
        ref.feedUrl,
        options: Options(
          headers: {
            if (ref.etag != null) 'If-None-Match': ref.etag,
            if (ref.lastModified != null) 'If-Modified-Since': ref.lastModified,
          },
        ),
      );

      if (response.statusCode == 304) return const FetchResult.unchanged();
      if (response.statusCode != 200) {
        return FetchResult.failed(
          'The address returns a ${response.statusCode}.',
        );
      }

      final body = response.data;
      if (body == null || body.trim().isEmpty) {
        return const FetchResult.failed('The feed returned an empty document.');
      }

      return FetchResult.fresh(
        // Parsed on a background isolate. A 300KB feed document costs
        // hundreds of milliseconds to parse, and forty-five of them in a row
        // on the UI thread is exactly what made the first briefing look
        // frozen. Nothing here touches the tree, so it ships out whole.
        articles: await compute(FeedParser.parse, body),
        etag: response.headers.value('etag'),
        lastModified: response.headers.value('last-modified'),
      );
    } on FormatException catch (e) {
      return FetchResult.failed(e.message);
    } on DioException catch (e) {
      return FetchResult.failed(_describe(e));
    }
  }

  static String _describe(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout => 'The feed took too long to answer.',
    DioExceptionType.connectionError => 'No connection to the feed.',
    DioExceptionType.badCertificate =>
      'The feed presented a certificate we could not verify.',
    _ => 'The feed could not be read.',
  };
}
