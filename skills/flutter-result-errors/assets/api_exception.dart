// core/network/api_exception.dart
import 'package:your_app/core/errors/errors.dart';

/// Infrastructure-level failure thrown by `ApiClient` implementations.
///
/// These never escape the data layer: `RemoteDataSourceGuard` catches
/// them and converts to [AppFailure] via [toAppFailure].
sealed class ApiException implements Exception {
  const ApiException({this.message});

  final String? message;
}

/// The request never produced a response: offline, DNS, timeouts.
final class ApiConnectionException extends ApiException {
  const ApiConnectionException({super.message});
}

/// The server answered with an error status code.
final class ApiResponseException extends ApiException {
  const ApiResponseException({
    this.statusCode,
    this.data,
    this.code,
    super.message,
  });

  final int? statusCode;

  /// The API's own error code, when the body carries one.
  final String? code;

  /// Decoded error body, when the server sent one.
  final Object? data;
}

/// Anything else that went wrong while performing the request.
final class ApiUnknownException extends ApiException {
  const ApiUnknownException({this.error, this.stackTrace, super.message});

  final Object? error;
  final StackTrace? stackTrace;
}

/// The single place HTTP semantics become domain semantics.
/// Adjust the status mapping to your API, but keep it here.
extension ApiExceptionToFailureX on ApiException {
  AppFailure toAppFailure() => switch (this) {
    ApiConnectionException(:final message) => NetworkFailure(message: message),
    ApiResponseException(:final statusCode, :final message, :final code) =>
      switch (statusCode) {
        401 || 403 => AuthFailure(message: message),
        422 => ValidationFailure(message: message),
        _ => ServerFailure(
          statusCode: statusCode,
          message: message,
          code: code,
        ),
      },
    ApiUnknownException(:final error, :final stackTrace, :final message) =>
      UnknownFailure(error: error, stackTrace: stackTrace, message: message),
  };
}
