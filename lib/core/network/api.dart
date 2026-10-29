import 'package:dio/dio.dart';

import '../errors/app_failure.dart';
import '../utils/json.dart';
import 'error_mapper.dart';
import 'paginated.dart';

/// Thin helpers shared by every feature's data source. They map errors to
/// [AppFailure], unwrap the response envelope and never send a GET body
/// (the host firewall answers 403 to that).
class Api {
  const Api(this.dio);
  final Dio dio;

  Future<Page<T>> page<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, Object?> query = const {},
    int page = 1,
    int perPage = 20,
  }) async {
    final res = await _guard(() => dio.get<dynamic>(
          path,
          queryParameters: cleanQuery({...query, 'page': page, 'per_page': perPage}),
        ));
    return Page.parse(res.data, fromJson);
  }

  Future<Object?> getData(String path, {Map<String, Object?> query = const {}}) async {
    final res = await _guard(() => dio.get<dynamic>(path, queryParameters: cleanQuery(query)));
    return unwrap(res.data);
  }

  Future<Object?> post(String path, Object body) async {
    final res = await _guard(() => dio.post<dynamic>(
          path,
          data: body,
          options: body is FormData ? null : Options(contentType: Headers.jsonContentType),
        ));
    return unwrap(res.data);
  }

  Future<Object?> put(String path, Map<String, Object?> body) async {
    final res = await _guard(() => dio.put<dynamic>(
          path,
          data: body,
          options: Options(contentType: Headers.jsonContentType),
        ));
    return unwrap(res.data);
  }

  Future<Response<dynamic>> _guard(Future<Response<dynamic>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      // GETs retry once on network trouble; writes never retry automatically.
      final retriable = e.requestOptions.method == 'GET' &&
          (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError);
      if (retriable) {
        try {
          return await call();
        } on DioException catch (e2) {
          throw mapError(e2);
        }
      }
      throw mapError(e);
    } catch (e) {
      throw mapError(e);
    }
  }
}
