import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../errors/app_failure.dart';
import '../storage/secure_store.dart';
import 'api.dart';

/// Called by the auth interceptor when the server rejects the token.
/// The auth feature overrides this to sign the user out.
final unauthorizedHandlerProvider = Provider<void Function()>((ref) => () {});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(_ApiInterceptor(ref));
  if (Env.isDev) {
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }
  return dio;
});

final apiProvider = Provider<Api>((ref) => Api(ref.watch(dioProvider)));

class _ApiInterceptor extends Interceptor {
  _ApiInterceptor(this._ref);
  final Ref _ref;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _ref.read(secureStoreProvider).readToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    // Unknown API paths currently return the web 404 page with status 200.
    final type = response.headers.value(Headers.contentTypeHeader) ?? '';
    final expectsBytes = response.requestOptions.responseType == ResponseType.bytes ||
        response.requestOptions.responseType == ResponseType.stream;
    if (!expectsBytes && type.contains('text/html')) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: const NotFoundFailure(),
        ),
      );
      return;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final isLogin = err.requestOptions.path.endsWith('/auth/login');
    if (err.response?.statusCode == 401 && !isLogin) {
      _ref.read(unauthorizedHandlerProvider)();
    }
    handler.next(err);
  }
}
