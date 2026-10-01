// core/errors/result.dart
//
// Replace `your_app` with the package name from pubspec.yaml.
import 'package:result_dart/result_dart.dart' hide AsyncResult, Result;
import 'package:your_app/core/errors/app_failure.dart';

// Re-exported so feature code imports `core/errors/errors.dart` and never
// `package:result_dart` directly: the package stays swappable behind
// application-owned names.
export 'package:result_dart/result_dart.dart' hide AsyncResult, Result;

/// Outcome of an operation that can fail with an [AppFailure].
/// `Result<Unit>` covers the ones that return no data.
typedef Result<S extends Object> = ResultDart<S, AppFailure>;

/// A [Result] that arrives asynchronously — the signature of every
/// repository and data-source method.
typedef AsyncResult<S extends Object> = Future<ResultDart<S, AppFailure>>;
