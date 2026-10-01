// core/utils/retry_policy.dart
//
// Riverpod 3 retries a provider that throws during build, with exponential
// backoff, by default. With Result-based errors that is usually wrong:
// an AuthFailure or ValidationFailure will fail identically every time.
//
// Check the `retry` signature against the Riverpod version you use.
import 'package:your_app/core/errors/errors.dart';

/// Retry only what can plausibly succeed on a second attempt, and only
/// a couple of times. Everything else surfaces to the UI immediately.
Duration? appRetry(int retryCount, Object error) {
  if (retryCount >= 2) return null;

  final retryable = switch (error) {
    NetworkFailure() => true,
    ServerFailure(:final statusCode) => (statusCode ?? 500) >= 500,
    _ => false,
  };
  if (!retryable) return null;

  return Duration(milliseconds: 300 * (1 << retryCount)); // 300ms, 600ms
}

// Install once, at the composition root:
//
//   ProviderContainer(overrides: overrides, retry: appRetry)
//   // or: ProviderScope(retry: appRetry, child: ...)
//
// Opt a single provider out when its work is not safe or cheap to repeat
// (store purchases, payments, anything that talks to a rate-limited SDK):
//
//   final purchaseProvider = AsyncNotifierProvider<PurchaseNotifier, Offer>(
//     PurchaseNotifier.new,
//     retry: (_, _) => null,
//   );
