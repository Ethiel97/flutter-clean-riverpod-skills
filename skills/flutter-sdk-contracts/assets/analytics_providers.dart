// core/analytics/analytics_providers.dart
//
// `FirebaseAnalyticsAdapter` / `PostHogAnalyticsAdapter` are YOUR adapters:
// classes `implements AnalyticsService` that are the only files importing
// the vendor SDK.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:your_app/core/analytics/analytics_config.dart';
import 'package:your_app/core/analytics/analytics_service.dart';
import 'package:your_app/core/analytics/composite_analytics_service.dart';

/// Disabled by default so widget and provider tests never initialize a
/// platform SDK. Bootstrap overrides this for real app runs.
final analyticsConfigProvider = Provider<AnalyticsConfig>(
  (_) => const AnalyticsConfig.disabled(),
);

/// One contract, zero to many destinations behind it. Feature code sees
/// neither the vendors nor how many there are.
final Provider<AnalyticsService> analyticsServiceProvider =
    Provider<AnalyticsService>((ref) {
      final config = ref.watch(analyticsConfigProvider);

      final services = <AnalyticsService>[
        if (config.postHogEnabled) PostHogAnalyticsAdapter(config),
        if (config.firebaseEnabled) FirebaseAnalyticsAdapter(),
      ];

      return switch (services.length) {
        0 => const NoOpAnalyticsService(),
        1 => services.single,
        _ => CompositeAnalyticsService(services),
      };
    });
