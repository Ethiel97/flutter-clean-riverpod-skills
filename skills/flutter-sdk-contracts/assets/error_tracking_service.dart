// core/error_tracking/error_tracking_service.dart
import 'package:your_app/core/errors/result.dart';

class ErrorTrackingUser {
  const ErrorTrackingUser({required this.id, this.email});

  final String id;
  final String? email;
}

/// Crash and error reporting owned by the application.
abstract interface class ErrorTrackingService {
  /// Never throws: reporting a failure must not fail the operation that
  /// produced it.
  Future<void> captureException(
    Object error,
    StackTrace? stackTrace, {

    /// What the backend groups the issue by, e.g. `social_auth.google`.
    String? context,

    /// Low-cardinality only. Never a token, never an email.
    Map<String, String> tags,
  });

  /// Not an event: a bounded buffer, sent only alongside a real error.
  Future<void> addBreadcrumb(String message, {Map<String, String> data});

  AsyncResult<Unit> identify(ErrorTrackingUser user);

  AsyncResult<Unit> clearIdentity();
}

/// What tests and builds without a DSN get.
class NoOpErrorTrackingService implements ErrorTrackingService {
  const NoOpErrorTrackingService();

  @override
  Future<void> captureException(
    Object error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, String> tags = const {},
  }) async {}

  @override
  Future<void> addBreadcrumb(
    String message, {
    Map<String, String> data = const {},
  }) async {}

  @override
  AsyncResult<Unit> identify(ErrorTrackingUser user) async => unit.toSuccess();

  @override
  AsyncResult<Unit> clearIdentity() async => unit.toSuccess();
}
