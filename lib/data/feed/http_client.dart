import 'dart:io';
import 'dart:typed_data';

import 'package:brotli/brotli.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';

/// A desktop browser's user agent.
///
/// Used for every request the app makes — feeds included. Several publishers
/// serve a 403, or a stripped image-free document, to anything that does not
/// look like a browser.
const browserUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

/// The one HTTP client in the app.
///
/// Conditional GET is the whole point: a refresh normally costs a 304 and no
/// body at all, which is what makes background refreshing cheap enough to be
/// invisible.
Dio buildHttpClient() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      followRedirects: true,
      maxRedirects: 5,
      responseType: ResponseType.plain,
      headers: const {
        // A browser's user agent, not ours. Publishers routinely refuse an
        // unknown client outright: Business Standard answered our own string
        // with a 403 and this one with the feed.
        'User-Agent': browserUserAgent,
        'Accept':
            'application/rss+xml, application/atom+xml, application/xml;q=0.9, '
            'text/xml;q=0.9, text/html;q=0.8, */*;q=0.5',
      },
      // 304 and 404 are answers, not exceptions — the pipeline reads the code.
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  dio
    ..httpClientAdapter = _Http2WhenOffered()
    ..interceptors.add(_RetryOnce(dio));
  return dio;
}

/// HTTP/2 wherever the server negotiates it, HTTP/1.1 everywhere else.
///
/// Dart's own `HttpClient` speaks HTTP/1.1 only, and some CDNs treat that as
/// a bot: NDTV's Akamai edge answers an HTTP/1.1 article request with 403 no
/// matter what headers it carries, and the same request over HTTP/2 with the
/// page. Plain `http://` goes straight to the 1.1 client — the h2 adapter
/// would try cleartext h2 and fail — and an `https://` host that does not
/// offer h2 in ALPN falls back the same way.
class _Http2WhenOffered implements HttpClientAdapter {
  final _h1 = IOHttpClientAdapter();
  late final _h2 = Http2Adapter(ConnectionManager(), fallbackAdapter: _h1);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.scheme != 'https') {
      return await _h1.fetch(options, requestStream, cancelFuture);
    }
    final body = await _h2.fetch(options, requestStream, cancelFuture);
    // The h2 adapter hands back the wire bytes; the 1.1 client inflates for
    // us. Both encodings a browser accepts are handled — The Hindu answers
    // `br` whatever preference the header states.
    final encoding = body.headers['content-encoding']?.join().toLowerCase();
    final Stream<Uint8List> decoded;
    switch (encoding) {
      case 'gzip':
        decoded = body.stream
            .cast<List<int>>()
            .transform(gzip.decoder)
            .map(Uint8List.fromList);
      case 'br':
        // Whole-buffer only: the decoder has no chunked form. A page is a
        // few hundred KB at most.
        decoded = Stream.fromFuture(
          body.stream
              .fold<BytesBuilder>(BytesBuilder(), (b, chunk) => b..add(chunk))
              .then((b) => Uint8List.fromList(brotli.decode(b.takeBytes()))),
        );
      default:
        return body;
    }
    body.headers.remove('content-encoding');
    return ResponseBody(
      decoded,
      body.statusCode,
      headers: body.headers,
      statusMessage: body.statusMessage,
      isRedirect: body.isRedirect,
      redirects: body.redirects,
    );
  }

  @override
  void close({bool force = false}) {
    _h2.close(force: force);
    _h1.close(force: force);
  }
}

/// Retries a request once on a transient failure. Feeds are flaky; a second
/// attempt costs little and spares the reader a false "not responding".
class _RetryOnce extends Interceptor {
  new(this._dio);

  final Dio _dio;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final retriable = switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      _ => false,
    };
    if (!retriable || err.requestOptions.extra['hsRetried'] == true) {
      return handler.next(err);
    }
    err.requestOptions.extra['hsRetried'] = true;
    try {
      handler.resolve(await _dio.fetch<dynamic>(err.requestOptions));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
