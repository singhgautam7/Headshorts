import 'package:dio/dio.dart';

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
        'User-Agent': 'HeadShorts/1.0 (+https://github.com/grs/headshorts)',
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
