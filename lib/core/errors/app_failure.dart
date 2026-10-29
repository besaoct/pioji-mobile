/// Every error a repository can return. Widgets never see `DioException`.
sealed class AppFailure implements Exception {
  const AppFailure();

  /// One user-facing sentence.
  String get message;
}

class OfflineFailure extends AppFailure {
  const OfflineFailure();
  @override
  String get message => "You're offline. Check your connection and try again.";
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure();
  @override
  String get message => 'The server is taking too long. Try again.';
}

class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([this.serverMessage]);
  final String? serverMessage;
  @override
  String get message => serverMessage ?? 'Your session expired. Sign in again.';
}

class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure();
  @override
  String get message => "You don't have access to this.";
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure();
  @override
  String get message => "We couldn't find that. It may have been removed.";
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(this.serverMessage, this.fieldErrors);
  final String serverMessage;
  final Map<String, String> fieldErrors;
  @override
  String get message =>
      fieldErrors.isEmpty ? serverMessage : 'Check the highlighted fields.';
}

class DuplicateFailure extends AppFailure {
  const DuplicateFailure(this.serverMessage);
  final String serverMessage;
  @override
  String get message => serverMessage;
}

class ServerFailure extends AppFailure {
  const ServerFailure([this.status]);
  final int? status;
  @override
  String get message => 'Something went wrong on our side. Try again.';
}

class UnknownFailure extends AppFailure {
  const UnknownFailure(this.error);
  final Object error;
  @override
  String get message => 'Something went wrong. Try again.';
}
