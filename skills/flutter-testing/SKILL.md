---
name: flutter-testing
description: Use when writing or reviewing tests for a Flutter app that uses Riverpod, Result-based repositories and SDKs behind contracts - unit tests for data sources, repositories and notifiers, widget tests with provider overrides, listener tests with recording fakes, golden tests, or deciding between a mock and a fake.
---

# Testing a contract-based Flutter app

The architecture makes testing cheap: every boundary is a contract you can
override. Test **behaviour at the boundaries**, not implementation details.

## Layout

```text
test/
├── helpers/            test_container.dart, pump_app.dart, fakes, helpers.dart (barrel)
├── core/               mirrors lib/core
├── features/<feature>/ mirrors lib/features/<feature>; goldens/ beside the test
└── shared/
```

One test file per source file, named `<file>_test.dart`. Group by class.

## Mock or fake

| Use | When |
|---|---|
| **Recording fake** (a hand-written class that implements the contract and stores what it received) | Stateful app-owned contracts: `AnalyticsService`, `ErrorTrackingService`, `NotificationService`. Assertions read as "this event was tracked". |
| **`mocktail` mock** | A repository or data-source contract with canned answers: `when(repo.getDashboard).thenAnswer((_) async => Success(dashboard))`. |
| **Fake `ApiClient`** | Testing a remote data source: throw an `ApiException`, assert the `Result`. Never mock Dio here. |
| **Mock `Dio`** | Only in the `DioApiClient` test itself. |

If you find yourself mocking an SDK inside a feature test, the SDK is not
behind a contract (see `flutter-sdk-contracts`).

## Helpers (copy from `assets/`)

- `test_container.dart`: `createContainer(overrides:)` disposes itself and turns
  **retry off**. Riverpod 3 retries failing providers with backoff by default,
  which makes failure assertions slow and flaky.
- `pump_app.dart`: `tester.pumpApp(widget, overrides:)` mounts under the real
  theme and localizations and returns the container.
- `recording_analytics_service.dart`: from the `flutter-sdk-contracts` assets.

## Recipes

**1. Data source: failure mapping**

```dart
test('maps 401 to AuthFailure', () async {
  final api = _FakeApiClient(throws: const ApiResponseException(statusCode: 401));
  final result = await ProfileRemoteDataSourceImpl(api).fetchProfile();
  expect(result.exceptionOrNull(), isA<AuthFailure>());
});
```

Cover: success, 401/403 → `AuthFailure`, 422 → `ValidationFailure`, 5xx →
`ServerFailure`, connection error → `NetworkFailure`, timeout → `NetworkFailure`,
anything else → `UnknownFailure`.

**2. Repository: model → entity**

Fake the data source, return a model, assert the entity. Also assert a failure
is passed through **unchanged**.

**3. Notifier**

```dart
test('loads items from the repository', () async {
  final repo = _MockItemRepository();
  when(repo.getPage).thenAnswer((_) async => Success(page));
  final container = createContainer(
    overrides: [itemRepositoryProvider.overrideWithValue(repo)],
  );

  final state = await container.read(itemsProvider.future);

  expect(state.items, page.items);
});
```

- Override the **repository contract**; `data/` is never touched.
- For `autoDispose` providers, hold a listener (`keepAlive` helper) or the
  provider can be disposed between reads.
- Replace a dependency notifier with a test subclass:
  `learningProvider.overrideWith(_RecordingLearningNotifier.new)`.

**4. Submission notifier: dispose mid-flight**

```dart
test('survives disposal while the action is in flight', () async {
  final completer = Completer<Result<String>>();
  final subscription = container.listen(provider, (_, _) {});
  final pending = container.read(provider.notifier).submit(completer.future);

  subscription.close();           // the screen goes away
  await container.pump();
  completer.complete(const Success('late'));

  await expectLater(pending, completion(isA<Success<String, AppFailure>>()));
});
```

Without the `ref.mounted` guard this throws after disposal.

**5. Widget**

```dart
testWidgets('shows an error with a retry', (tester) async {
  await tester.pumpApp(
    const ItemsPage(),
    overrides: [itemRepositoryProvider.overrideWithValue(_FailingRepository())],
  );
  await tester.pumpAndSettle();
  expect(find.text('Try again'), findsOneWidget);
});
```

**6. Listener widget**

Mount only the listener over an empty child with `UncontrolledProviderScope`,
override the contracts (recording analytics, mock repository), drive the state
and assert:

```dart
final analytics = RecordingAnalyticsService();
final container = createContainer(overrides: [
  analyticsServiceProvider.overrideWithValue(analytics),
]);
await tester.pumpWidget(UncontrolledProviderScope(
  container: container,
  child: const ItemsListeners(child: SizedBox()),
));

container.read(itemSubmissionProvider.notifier).add();
await tester.pump();

expect(analytics.events.single, isA<ItemChangedEvent>());
```

End by unmounting (`await tester.pumpWidget(const SizedBox())`) before the
container is disposed.

**7. `DioApiClient`**

Mock `Dio` and assert exception mapping: timeouts and connection errors →
`ApiConnectionException`, bad responses → `ApiResponseException` with status
and `code`, anything else → `ApiUnknownException`. Stub the same method the
adapter calls (`dio.request<Map<String, dynamic>>(...)` in the reference
adapter).

**8. Goldens** — `assets/golden_test_template.dart`

- Tag them (`@Tags(['golden'])`) so they can be run or skipped separately.
- Load one known font; fix the surface size and `devicePixelRatio`.
- One golden per visual **state**, and per shipped **locale** (copy length changes layout).
- Generate and compare on **one OS** in CI; font rendering differs across platforms.
- Update deliberately: `flutter test --tags golden --update-goldens`.

**9. Pin framework behaviour you rely on**

When a feature depends on a library behaviour that is not yours to guarantee
(for example, a failed refetch keeps the previous value so pull-to-refresh can
report the error without blanking the list), write a small test that asserts it:

```dart
expect(state, isA<AsyncError<String>>());
expect(state.hasValue, isTrue);   // failed AND still holds the old value
```

A package upgrade that drops it then fails a test instead of showing up as
vanishing content on a bad connection, far from any code you changed.

## Principles

- **Arrange with overrides, not with real wiring.** If a test needs `Dio` or
  Firebase, a contract is missing.
- **Assert outcomes**: state, events recorded, entities returned. Avoid
  `verify(...).called(n)` unless the call count *is* the behaviour.
- **Regression first.** A bug fix starts with a failing test that names the bug
  in a comment: why it failed, not only what was asserted.
- **No `sleep`.** Use `tester.pump(duration)`, `fake_async`, or `container.pump()`.
- **Dispose** every `ProviderContainer` (`addTearDown`).
- Verify layer rules separately with `check_boundaries.sh` from
  `flutter-feature-scaffold`; tests are not the place for import hygiene.

## Review checklist

- [ ] Overrides at the contract boundary; no SDK or Dio mocked in feature tests
- [ ] Recording fakes for stateful services, mocks for canned repository answers
- [ ] Retry disabled in test containers; containers disposed
- [ ] Every failure branch of a data source has a test
- [ ] Notifier tests cover load success, load failure, and a mutation failure that keeps state
- [ ] Goldens tagged, one per state and locale, generated on one OS
- [ ] A regression test accompanies each bug fix
