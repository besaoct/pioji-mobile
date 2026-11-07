import 'dart:io';

import 'package:dio/dio.dart';

import '../errors/app_failure.dart';

AppFailure mapError(Object error) {
  if (error is AppFailure) return error;
  if (error is! DioException) return UnknownFailure(error);
  if (error.error is AppFailure) return error.error! as AppFailure;

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const OfflineFailure();
    case DioExceptionType.unknown:
      if (error.error is SocketException) return const OfflineFailure();
      return UnknownFailure(error);
    case DioExceptionType.badResponse:
      break;
    default:
      return UnknownFailure(error);
  }

  final status = error.response?.statusCode;
  final body = error.response?.data;
  final serverMessage = body is Map ? body['message']?.toString() : null;

  switch (status) {
    case 401:
      return UnauthorizedFailure(serverMessage);
    case 403:
      return const ForbiddenFailure();
    case 404:
      return const NotFoundFailure();
    case 409:
      return DuplicateFailure(serverMessage ?? 'This invoice already exists.');
    case 422:
      final fields = <String, String>{};
      final errors = body is Map ? body['errors'] : null;
      if (errors is Map) {
        errors.forEach((key, value) {
          final first = value is List && value.isNotEmpty ? value.first : value;
          if (first != null) fields[key.toString()] = first.toString();
        });
      }
      final msg = serverMessage ?? 'Check the highlighted fields.';
      if (looksDuplicate(msg) || fields.values.any(looksDuplicate)) {
        return DuplicateFailure(fields.values.firstWhere(looksDuplicate, orElse: () => msg));
      }
      return ValidationFailure(msg, fields);
  }
  return ServerFailure(status, serverMessage);
}

bool looksDuplicate(String text) {
  final t = text.toLowerCase();
  return t.contains('duplicate') || t.contains('already exists');
}
