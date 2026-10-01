// test/helpers/recording_analytics_service.dart
import 'package:your_app/core/analytics/analytics.dart';
import 'package:your_app/core/errors/errors.dart';

/// Test double that records instead of sending. Prefer this over mocking:
/// assertions read as "this event was tracked", not "this method was called".
class RecordingAnalyticsService implements AnalyticsService {
  final List<AnalyticsEvent> events = [];
  final List<String> screens = [];
  final List<String> identities = [];
  int resetCount = 0;
  int initializeCount = 0;

  @override
  AsyncResult<Unit> initialize() async {
    initializeCount++;
    return const Success(unit);
  }

  @override
  AsyncResult<Unit> track(AnalyticsEvent event) async {
    events.add(event);
    return const Success(unit);
  }

  @override
  AsyncResult<Unit> screen(String screenName) async {
    screens.add(screenName);
    return const Success(unit);
  }

  @override
  AsyncResult<Unit> identify(String userId) async {
    identities.add(userId);
    return const Success(unit);
  }

  @override
  AsyncResult<Unit> resetIdentity() async {
    resetCount++;
    return const Success(unit);
  }
}

// In a test:
//   final analytics = RecordingAnalyticsService();
//   await tester.pumpWidget(ProviderScope(
//     overrides: [analyticsServiceProvider.overrideWithValue(analytics)],
//     child: const MyPage(),
//   ));
//   expect(analytics.events.single, isA<AuthCompletedEvent>());
