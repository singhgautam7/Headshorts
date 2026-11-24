import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
  const new(this._dio, {this.deadline = const Duration(seconds: 15)});

  final Dio _dio;

  /// The whole attempt, retry included. Past it the request is cancelled, not
  /// just abandoned, so the socket does not keep running to Dio's own limits.
  final Duration deadline;

  /// The largest feed document read. A feed is a few hundred KB; anything
  /// past this is not one, and buffering it would cost the phone its memory.
  static const maxBytes = 8 * 1024 * 1024;

  @override
  bool canHandle(SourceType type) => type == SourceType.rss;

  @override
  Future<FetchResult> fetch(SourceRef ref) async {
    final cancel = CancelToken();
    final timer = Timer(deadline, () => cancel.cancel('deadline'));
    try {
      final response = await _dio.get<ResponseBody>(
        ref.feedUrl,
        cancelToken: cancel,
        options: Options(
          // Streamed, so the size cap bites while the bytes arrive.
          responseType: ResponseType.stream,
          headers: {
            if (ref.etag != null) 'If-None-Match': ref.etag,
            if (ref.lastModified != null) 'If-Modified-Since': ref.lastModified,
          },
        ),
      );

      final status = response.statusCode;
      if (status == 304) return const FetchResult.unchanged();
      if (status != 200) {
        return FetchResult.failed(_describeStatus(status));
      }

      final declared = int.tryParse(
        response.headers.value(Headers.contentLengthHeader) ?? '',
      );
      if (declared != null && declared > maxBytes) {
        return const FetchResult.failed(_tooLarge);
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.data!.stream) {
        bytes.add(chunk);
        if (bytes.length > maxBytes) return const FetchResult.failed(_tooLarge);
      }
      final body = utf8.decode(bytes.takeBytes(), allowMalformed: true);
      if (body.trim().isEmpty) {
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
    } finally {
      timer.cancel();
      // Releases the socket of a body that was never read to the end.
      if (!cancel.isCancelled) cancel.cancel('done');
    }
  }

  static const _tooLarge = 'The feed is too large to read.';

  static String _describeStatus(int? status) => switch (status) {
    429 => 'The publisher is limiting requests. It will be tried again later.',
    _ => 'The address returns a $status.',
  };

  static String _describe(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.cancel => 'The feed took too long to answer.',
    DioExceptionType.badResponse =>
      (e.response?.statusCode ?? 0) >= 500
          ? "The publisher's server had a problem. It will be tried again "
                'later.'
          : 'The feed could not be read.',
    DioExceptionType.connectionError => 'No connection to the feed.',
    DioExceptionType.badCertificate =>
      'The feed presented a certificate we could not verify.',
    _ => 'The feed could not be read.',
  };
}
