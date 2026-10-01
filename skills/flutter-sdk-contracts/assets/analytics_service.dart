// core/analytics/analytics_service.dart
import 'package:your_app/core/analytics/analytics_event.dart';
import 'package:your_app/core/errors/result.dart';

/// Product analytics capability owned by the application.
///
/// External SDK types never cross this boundary.
abstract interface class AnalyticsService {
  /// Readies the provider before the first widget builds.
  AsyncResult<Unit> initialize();

  AsyncResult<Unit> track(AnalyticsEvent event);

  /// Separate from [track] because a screen view is a first-class
  /// primitive for most providers: they expose a dedicated call that feeds
  /// their screen reporting. A plain custom event leaves those views empty.
  AsyncResult<Unit> screen(String screenName);

  AsyncResult<Unit> identify(String userId);

  /// Clears the analytics identity after sign-out.
  AsyncResult<Unit> resetIdentity();
}

/// What tests and builds with analytics disabled get.
class NoOpAnalyticsService implements AnalyticsService {
  const NoOpAnalyticsService();

  @override
  AsyncResult<Unit> initialize() async => unit.toSuccess();

  @override
  AsyncResult<Unit> track(AnalyticsEvent event) async => unit.toSuccess();

  @override
  AsyncResult<Unit> screen(String screenName) async => unit.toSuccess();

  @override
  AsyncResult<Unit> identify(String userId) async => unit.toSuccess();

  @override
  AsyncResult<Unit> resetIdentity() async => unit.toSuccess();
}
