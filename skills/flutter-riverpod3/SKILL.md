---
name: flutter-riverpod3
description: Use when writing or reviewing Riverpod 3 code in a Flutter app WITHOUT code generation - choosing a provider type, wiring dependency injection, writing Notifier or AsyncNotifier classes, using ref.watch / read / listen / select, handling disposal, mounted checks and automatic retry, or when someone proposes riverpod_generator, @riverpod, StateNotifier, Bloc, GetIt or the provider package.
---

# Riverpod 3 without code generation

Riverpod is the only tool for **dependency injection, state management and
async orchestration**. Providers are declared explicitly by hand.

## Rules and why

| Rule | Why |
|---|---|
| No `riverpod_generator`, `riverpod_annotation`, `@riverpod` | One less `build_runner` target, the dependency graph is readable in plain Dart, and nothing to migrate when the generator's output changes. (`build_runner` may still run for `json_serializable` etc.) |
| No `StateNotifier` / `StateNotifierProvider` | Legacy API. `Notifier` / `AsyncNotifier` replace it. |
| No Bloc, Cubit, `provider` package, GetIt, Injectable | A second state or DI system doubles what a reader must learn and splits the graph. |
| Every dependency is exposed through a `Provider` | One graph, one override mechanism for tests. |
| Never instantiate dependencies inside widgets | A widget that does `Dio()` or `Repo()` cannot be tested or swapped. |

## Pick the provider by role

| Need | Use |
|---|---|
| Immutable dependency (repository, service, client) | `Provider<Contract>` |
| Async read-only data | `FutureProvider` |
| Continuous stream (auth state, connectivity) | `StreamProvider` |
| Mutable synchronous state (filters, selected tab, a form) | `NotifierProvider` |
| Mutable asynchronous state (a screen's store, a session) | `AsyncNotifierProvider` |
| One user action in flight | `SubmissionNotifier` + `autoDispose` (see `flutter-result-errors`) |

One responsibility per provider. Name them `xProvider` / `XNotifier`.

```dart
final todayProvider = FutureProvider<Today>((ref) async {
  final result = await ref.watch(todayRepositoryProvider).getToday();
  return result.getOrThrow(); // the sanctioned throw: becomes AsyncError
});
```

## `watch`, `read`, `listen`

| Where | Use | Never |
|---|---|---|
| Provider body, `Notifier.build`, widget `build` | `ref.watch` | `ref.read` for data that can change: the consumer will not update |
| Callbacks, notifier methods, `onPressed` | `ref.read` | `ref.watch`: it throws or leaks |
| Side effects (navigation, snackbar, analytics) | `ref.listen` in a listener widget (see `flutter-ui-side-effects`) | Doing them inside `build` |

## State classes

- State is **immutable** and extends `Equatable`. Riverpod only notifies when
  the new state is not `==` to the old one, and `select` compares by value, so
  value equality is what makes both work as intended.
- Mutate with `state = AsyncData(current.copyWith(...))`; never mutate a list
  in place (the reference does not change, so nothing fires).
- On a failed reload or load-more, **keep the previous state** and drop only the
  spinner. Blanking what the user is reading is worse than a stale list.
- Mutating methods return `AsyncResult` so the caller can report the failure;
  the store itself changes **only on success**, so a failed attempt never wipes
  app-wide state. Template: `assets/async_store_notifier.dart`.

## Lifecycle

- **`autoDispose`** for screen-scoped state and for per-attempt submissions, so
  a stale error resets when the screen is left.
- **Never `autoDispose`** a long-lived singleton that is read from callbacks
  (a text-to-speech engine, a socket): it can be torn down mid-use and crash on
  the next event. Release native resources with `ref.onDispose`.
- **`ref.onDispose`** for every timer, debouncer and stream subscription a
  provider creates.
- **`if (!ref.mounted) return;` after every `await`** in a notifier that can be
  disposed while a request is in flight; assigning `state` afterwards throws.
  Still hand the result back to the caller.
- `ref.invalidate(provider)` is the retry button: wire `onRetry` to it.

## Automatic retry (Riverpod 3)

A provider that throws during `build` is **retried automatically** with
exponential backoff. With Result-based errors that is usually wrong:
an `AuthFailure` or `ValidationFailure` fails identically every time, and
calling a store or payment SDK ten more times is harmful.

- Install one policy at the composition root that retries only
  `NetworkFailure` and 5xx, a couple of times: `assets/retry_policy.dart`.
- Opt out per provider with `retry: (_, _) => null` when the work is not safe
  to repeat.
- Tests switch retry off (see `flutter-testing`).

Verify the `retry` parameter against your Riverpod version.

## Composition root

- A **required** config provider throws until overridden, so a missing override
  fails at startup rather than mid-session.
- An **optional** capability defaults to a disabled/no-op config so tests never
  initialise a platform SDK.
- Build the `ProviderContainer` yourself and use `UncontrolledProviderScope`
  when something must read providers before the first frame, or when a widget
  above the router needs the router instance. See `assets/bootstrap_example.dart`.
- A widget placed above the router cannot use `context.router`; read the router
  from a provider instead.

## Rebuild performance

Measure first. These techniques add complexity; use them when a rebuild is
**observably** expensive (a long list, a chart, dropped frames), not on suspicion.

1. **Push the `watch` down.** A small `ConsumerWidget` around the subtree that
   needs the state beats a `select` at the page root. Listener widgets exist
   for the same reason: they listen without watching.
2. **Keep transient state out of app-wide providers.** A submission in flight
   belongs in its own `autoDispose` provider, not in the session, or every
   screen watching the session rebuilds on every tap.
3. **`select` the narrowest thing.**
   ```dart
   final name = ref.watch(authProvider.select((s) => s.value?.user?.name ?? ''));
   final submitting = ref.watch(submissionProvider.select((s) => s.isLoading));
   ```
   Use `selectAsync` to derive from another provider's *data* without awaiting
   the whole `AsyncValue`.
4. **`const` the leaves.**

`select` rules: the selected value must be immutable and compared by value;
do not select a property that changes as often as its parent.

## Anti-patterns

- `ref.read` inside `build` for reactive data
- A provider that holds business rules which belong in the domain
- Reading `failure.message` for UI copy (see `flutter-result-errors`)
- Catching an error inside a provider to swallow it: fold the `Result` instead
- A single giant provider that every screen watches
- Creating a `ProviderContainer` inside a widget

## Review checklist

- [ ] No generator, annotation, `StateNotifier`, Bloc, GetIt, `provider` package
- [ ] Each provider has one job and the right type for it
- [ ] `watch` in builds, `read` in callbacks, `listen` for side effects
- [ ] State classes are immutable and `Equatable`
- [ ] `autoDispose` where scoped; never on long-lived singletons
- [ ] `ref.mounted` checked after awaits; `ref.onDispose` for timers and subscriptions
- [ ] A retry policy is installed; unsafe providers opt out
- [ ] Required config providers throw until overridden
