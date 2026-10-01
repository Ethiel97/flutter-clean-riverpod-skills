// core/errors/app_failure.dart

/// Domain failure taxonomy.
///
/// Every failure that crosses a repository boundary is one of these.
/// Sealed so presentation folds are exhaustive — adding a new failure
/// type is a compile error everywhere it isn't handled.
sealed class AppFailure {
  const AppFailure({this.message});

  /// Optional human-oriented detail for logging; UI copy should come
  /// from l10n keyed on the failure type, not from this string.
  final String? message;

  /// Spelled out per subclass: minification turns `runtimeType` into a
  /// single letter in release, where logs are hardest to get hold of.
  String get kind;

  /// Names the type and carries the detail. Without it every log line
  /// reads "Instance of 'UnknownFailure'".
  @override
  String toString() {
    final detail = message;
    return detail == null || detail.isEmpty ? kind : '$kind: $detail';
  }
}

/// Device is offline or the request never reached the server.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.message});

  @override
  String get kind => 'NetworkFailure';
}

/// The server answered with an error status.
final class ServerFailure extends AppFailure {
  const ServerFailure({this.statusCode, this.code, super.message});

  final int? statusCode;

  /// Machine-readable code from the API's error body, when it has one.
  final String? code;

  @override
  String get kind => 'ServerFailure';

  @override
  String toString() => '${super.toString()} (status: $statusCode, code: $code)';
}

/// The user is not authenticated or the session expired.
final class AuthFailure extends AppFailure {
  const AuthFailure({super.message});

  @override
  String get kind => 'AuthFailure';
}

/// The input or response failed validation.
final class ValidationFailure extends AppFailure {
  const ValidationFailure({super.message});

  @override
  String get kind => 'ValidationFailure';
}

/// Local persistence (cache, secure storage, preferences) failed.
final class CacheFailure extends AppFailure {
  const CacheFailure({super.message});

  @override
  String get kind => 'CacheFailure';
}

/// The user backed out of a flow they opened themselves.
///
/// A failure only in the sense that no value came back: it is an answer,
/// not a fault, and the UI must stay silent rather than apologise for
/// obeying.
final class CancelledFailure extends AppFailure {
  const CancelledFailure({super.message});

  @override
  String get kind => 'CancelledFailure';
}

/// Anything unexpected; carries the original error for reporting.
final class UnknownFailure extends AppFailure {
  const UnknownFailure({this.error, this.stackTrace, super.message});

  final Object? error;
  final StackTrace? stackTrace;

  @override
  String get kind => 'UnknownFailure';

  /// The wrapped error is the whole point of this type: hiding it turns
  /// every unexpected failure into the same unreadable line.
  @override
  String toString() => '${super.toString()} (error: $error)';
}
