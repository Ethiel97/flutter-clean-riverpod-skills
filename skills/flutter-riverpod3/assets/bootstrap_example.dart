// app/bootstrap.dart  (shape of the composition root)
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:your_app/core/utils/retry_policy.dart';

/// The one place that knows the real environment. Everything else asks a
/// provider.
Future<void> bootstrap(Widget Function() builder, AppEnvironment env) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Required config providers throw until overridden here, so a missing
  // override fails loudly at startup instead of mid-session:
  //
  //   final networkConfigProvider = Provider<NetworkConfig>(
  //     (ref) => throw UnimplementedError('override in bootstrap'),
  //   );
  final overrides = <Override>[
    appEnvironmentProvider.overrideWithValue(env),
    networkConfigProvider.overrideWithValue(NetworkConfig(baseUrl: env.apiUrl)),
    analyticsConfigProvider.overrideWithValue(env.analytics),
  ];

  // Build the container yourself (not ProviderScope) when something must
  // read providers BEFORE the first frame: warm-up work, SDK init, or
  // handing the same router instance to a listener that lives above it.
  final container = ProviderContainer(overrides: overrides, retry: appRetry);

  await container.read(analyticsServiceProvider).initialize();

  runApp(UncontrolledProviderScope(container: container, child: builder()));
}
