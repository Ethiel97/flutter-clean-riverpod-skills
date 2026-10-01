// core/analytics/composite_analytics_service.dart
import 'package:your_app/core/analytics/analytics_event.dart';
import 'package:your_app/core/analytics/analytics_service.dart';
import 'package:your_app/core/errors/errors.dart';

/// Sends every call to several destinations behind one contract, so
/// feature code never learns that there is more than one.
class CompositeAnalyticsService implements AnalyticsService {
  const CompositeAnalyticsService(this._services);

  final List<AnalyticsService> _services;

  @override
  AsyncResult<Unit> initialize() => _fanOut((s) => s.initialize());

  @override
  AsyncResult<Unit> track(AnalyticsEvent event) => _fanOut((s) => s.track(event));

  @override
  AsyncResult<Unit> screen(String screenName) =>
      _fanOut((s) => s.screen(screenName));

  @override
  AsyncResult<Unit> identify(String userId) => _fanOut((s) => s.identify(userId));

  @override
  AsyncResult<Unit> resetIdentity() => _fanOut((s) => s.resetIdentity());

  /// Every destination is called even after one fails: a broken SDK must
  /// not cost the others their event. The first failure is returned so it
  /// stays visible, rather than reporting success on partial delivery.
  AsyncResult<Unit> _fanOut(
    AsyncResult<Unit> Function(AnalyticsService service) call,
  ) async {
    AppFailure? firstFailure;

    for (final service in _services) {
      final result = await call(service);
      result.onFailure((failure) => firstFailure ??= failure);
    }

    final failure = firstFailure;
    return failure == null ? const Success(unit) : Failure(failure);
  }
}
