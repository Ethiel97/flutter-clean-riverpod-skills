// test/features/<feature>/<widget>_golden_test.dart
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/l10n/l10n.dart';
import 'package:your_app/shared/theme/theme.dart';

const _font = 'GoldenTestFont';

/// Golden images drift when glyphs come from different fonts, so load ONE
/// known font. Generate and compare goldens on the same OS in CI.
Future<void> _loadFonts() async {
  final arial = File('/System/Library/Fonts/Supplemental/Arial.ttf');
  if (arial.existsSync()) {
    final bytes = await arial.readAsBytes();
    await (FontLoader(_font)..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
  }
  // Icon fonts render as empty boxes unless loaded explicitly:
  // final icons = await rootBundle.load('packages/<icon_pkg>/assets/<font>.ttf');
  // await (FontLoader('packages/<icon_pkg>/<Family>')..addFont(Future.value(icons))).load();
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  Size size = const Size(390, 420),
}) async {
  // Fixed surface and pixel ratio: the same PNG on every machine.
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: () {
          final theme = AppTheme.light();
          return theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: _font),
          );
        }(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);

  // One golden per visual STATE, named after the state.
  testWidgets('summary card with a reminder', (tester) async {
    await _pump(tester, const SummaryCard(reminder: true));
    await expectLater(
      find.byType(SummaryCard),
      matchesGoldenFile('goldens/summary_card_reminder.png'),
    );
  });

  // Localised copy has different lengths: one golden per locale you ship.
  testWidgets('summary card, French', (tester) async {
    await _pump(tester, const SummaryCard(reminder: true), locale: const Locale('fr'));
    await expectLater(
      find.byType(SummaryCard),
      matchesGoldenFile('goldens/summary_card_reminder_fr.png'),
    );
  });
}

// Update after an intended visual change:
//   flutter test --tags golden --update-goldens
// Skip them locally when they are not the point:
//   flutter test --exclude-tags golden
