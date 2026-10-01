// test/helpers/pump_app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/l10n/l10n.dart';
import 'package:your_app/shared/theme/theme.dart';

extension PumpApp on WidgetTester {
  /// Mounts [widget] under the real theme and localizations, with provider
  /// [overrides]. Returns the container so a test can read and drive state.
  ///
  /// If your pages resolve a router in `build` (e.g. `context.router`),
  /// wrap `home:` with your router's scope here once, so no test has to.
  Future<ProviderContainer> pumpApp(
    Widget widget, {
    List<Override> overrides = const [],
    Locale locale = const Locale('en'),
  }) async {
    final container = ProviderContainer(
      overrides: overrides,
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);

    await pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: widget,
        ),
      ),
    );
    return container;
  }
}
