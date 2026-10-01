// core/network/remote_data_source_guard.dart
import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart' show protected;
import 'package:your_app/core/errors/errors.dart';
import 'package:your_app/core/network/api_exception.dart';

const Duration _defaultTimeout = Duration(seconds: 10);

/// The single catch boundary for remote data sources.
///
/// [guard] runs a request and folds infrastructure exceptions into the
/// [AppFailure] taxonomy, so no exception ever crosses a data-source
/// boundary. Being the one funnel also makes it the natural hook point
/// for error tracking: instrument here, cover every call.
mixin RemoteDataSourceGuard {
  /// Override per data source when an endpoint is legitimately slow
  /// (uploads, report generation).
  @protected
  Duration get requestTimeout => _defaultTimeout;

  @protected
  AsyncResult<T> guard<T extends Object>(Future<T> Function() request) async {
    try {
      return (await request().timeout(requestTimeout)).toSuccess();
    } on TimeoutException catch (e, stackTrace) {
      log('TimeoutException: $e', stackTrace: stackTrace);
      return Failure(NetworkFailure(message: '$e'));
    } on ApiException catch (e, stackTrace) {
      log('ApiException: $e', stackTrace: stackTrace);
      return Failure(e.toAppFailure());
    } on Object catch (e, s) {
      log('Unknown error: $e', stackTrace: s);
      return Failure(UnknownFailure(message: '$e', error: e, stackTrace: s));
    }
  }
}
