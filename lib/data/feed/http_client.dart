import 'package:dio/dio.dart';

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
  dio.interceptors.add(_RetryOnce(dio));
  return dio;
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
