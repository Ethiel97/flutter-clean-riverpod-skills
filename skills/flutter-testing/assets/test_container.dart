// test/helpers/test_container.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A container that cleans up after itself and never retries.
///
/// Riverpod 3 retries a failing provider with backoff by default. In a
/// test that turns "assert the failure" into a slow, flaky wait, so switch
/// it off here. Check the `retry` parameter against your Riverpod version.
ProviderContainer createContainer({List<Override> overrides = const []}) {
  final container = ProviderContainer(
    overrides: overrides,
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  return container;
}

/// Keeps an `autoDispose` provider alive for the duration of a test.
/// Without a listener it can be disposed between two reads.
T keepAlive<T>(ProviderContainer container, ProviderListenable<T> provider) {
  final subscription = container.listen(provider, (_, _) {});
  addTearDown(subscription.close);
  return subscription.read();
}
