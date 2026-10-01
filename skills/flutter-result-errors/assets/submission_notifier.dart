// core/utils/submission_notifier.dart
import 'dart:async';

import 'package:flutter/foundation.dart' show protected;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide AsyncResult;
import 'package:your_app/core/errors/result.dart';

/// Base for per-attempt action state: idle is `AsyncData(null)`,
/// [run] flips to loading, then folds the [Result] into data or error.
///
/// The store notifier a subclass calls mutates only on success, so a
/// failed attempt never wipes app-wide state. Declare the provider
/// `autoDispose` so a stale error resets when the screen is left.
abstract class SubmissionNotifier<T extends Object>
    extends Notifier<AsyncValue<T?>> {
  @override
  AsyncValue<T?> build() {
    // Not const: a const constructor can't capture T, so it would
    // silently infer AsyncData<Null> and break typed equality.
    return AsyncData<T?>(null);
  }

  @protected
  Future<Result<T>?> run(AsyncResult<T> Function() action) async {
    if (state.isLoading) return null; // double-tap guard
    state = AsyncLoading<T?>();
    final result = await action();
    // The provider is autoDispose and the action outlives the screen:
    // leaving mid-request disposes it while the request is in flight,
    // and assigning state then throws. The caller still gets the result —
    // only the state it would have driven is gone with its listeners.
    if (!ref.mounted) return result;

    state = result.fold(
      AsyncData.new,
      (failure) => AsyncValue.error(failure, StackTrace.current),
    );

    return result;
  }
}
