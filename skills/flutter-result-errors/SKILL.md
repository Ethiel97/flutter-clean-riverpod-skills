---
name: flutter-result-errors
description: Use when writing or reviewing Flutter data-layer, repository or provider code that can fail, when adding Result/AsyncResult types or failure types, when mapping exceptions to user-facing errors, or when an exception is crossing a layer boundary. Sets up a sealed AppFailure taxonomy, Result typedefs over result_dart, one catch boundary (RemoteDataSourceGuard) and the way presentation folds failures.
---

# Result-based error handling for Flutter

Nothing throws across a layer boundary. Every data-source and repository
method returns a `Result` that is either a value or an `AppFailure`.

## Why

- A thrown exception is invisible in a method signature; a `Result` is not.
  Callers cannot forget the failure path.
- `AppFailure` is **sealed**, so a `switch` over it is exhaustive. Adding a
  failure type becomes a compile error everywhere it is not handled.
- Exactly one place catches infrastructure exceptions, so mapping,
  logging and error reporting live in one funnel instead of N try/catch.

## Setup (once per project)

Copy these from this skill's `assets/` and replace `your_app` with the
package name in `pubspec.yaml`. Add `result_dart` to dependencies.

| Asset | Destination |
|---|---|
| `app_failure.dart`, `result.dart`, `errors.dart` | `lib/core/errors/` |
| `api_exception.dart`, `remote_data_source_guard.dart` | `lib/core/network/` |
| `submission_notifier.dart` | `lib/core/utils/` |

Feature code imports `core/errors/errors.dart`, **never**
`package:result_dart` directly, so the package stays swappable.
Where a file also imports `flutter_riverpod`, use
`import 'package:flutter_riverpod/flutter_riverpod.dart' hide AsyncResult;`
to avoid a name clash with the app typedef.

## Layer responsibilities

| Layer | Does | Never |
|---|---|---|
| Remote data source | Wraps every request in `guard(...)`; parses JSON into models | Contains `try/catch`; returns entities |
| Repository | Calls data sources, maps models → entities with `result.map(...)` | Catches, throws, or leaks models/DTOs |
| Domain | Pure Dart | Throws or catches |
| Presentation | Folds the `Result` into UI state | Reads `failure.message` for UI copy |

## Writing a data source

```dart
class WordRemoteDataSourceImpl
    with RemoteDataSourceGuard
    implements WordRemoteDataSource {
  WordRemoteDataSourceImpl(this._apiClient);
  final ApiClient _apiClient;

  @override
  AsyncResult<ProfileModel> fetchProfile() {
    return guard(() async {
      final response = await _apiClient.get(WordEndpoints.today);
      final data = response['data'] as Map<String, dynamic>;
      return ProfileModel.fromJson(data);
    });
  }
}
```

`guard` already handles timeouts (→ `NetworkFailure`), `ApiException`
(→ via `toAppFailure()`), and anything else (→ `UnknownFailure` carrying the
error and stack trace). Do not add a second `try/catch` around it.

Operations that return no data use `AsyncResult<Unit>`:

```dart
AsyncResult<Unit> deleteAccount() => guard(() async {
  await _apiClient.delete(AccountEndpoints.me);
  return unit;
});
```

## Writing a repository

The repository only converts; it passes failures through untouched.

```dart
@override
AsyncResult<Profile> getProfile() async {
  final result = await _remote.fetchProfile();
  return result.map((model) => model.toEntity());
}

@override
AsyncResult<Unit> deleteAccount() async {
  final result = await _remote.deleteAccount();
  return result.map((_) => unit);
}
```

## Consuming in presentation

**Reads** — bridge into Riverpod's `AsyncValue`. `getOrThrow()` inside a
provider is the one sanctioned throw: it surfaces as `AsyncError` to the UI.

```dart
class StatsNotifier extends AsyncNotifier<Stats> {
  @override
  Future<Stats> build() async {
    final result = await ref.watch(statsRepositoryProvider).getStats();
    return result.getOrThrow();
  }
}
```

**Actions** (submit, toggle, delete) — extend `SubmissionNotifier<T>` so a
button press gets loading / data / error state without `setState`:

```dart
class FavoriteSubmissionNotifier extends SubmissionNotifier<Unit> {
  Future<void> remove(String id) =>
      run(() => ref.read(favoritesProvider.notifier).remove(id));
}

final favoriteSubmissionProvider =
    NotifierProvider.autoDispose<FavoriteSubmissionNotifier, AsyncValue<Unit?>>(
      FavoriteSubmissionNotifier.new,
    );
```

Idle is `AsyncData(null)`. The notifier is `autoDispose` so a stale error
resets when the screen is left. `run` ignores a second call while loading
(double-tap guard) and survives the provider being disposed mid-request.

**UI copy** comes from l10n keyed on the failure *type*:

```dart
String failureMessage(AppLocalizations l10n, AppFailure failure) =>
    switch (failure) {
      NetworkFailure() => l10n.errorNetwork,
      AuthFailure() => l10n.errorSessionExpired,
      CancelledFailure() => '', // an answer, not a fault: stay silent
      _ => l10n.errorGeneric,
    };
```

Drop the `_` arm if you want the compiler to force every new failure to
be handled. Keep it when a feature-specific mapper falls back to a shared
baseline (match domain failures first, then delegate).

## Extending the taxonomy

Add a `final class XFailure extends AppFailure` (with its own `kind`) when
the UI must treat a case differently from the generic ones, e.g.
`CancelledFailure` (silent), a store refusing purchases, a social sign-in
sheet dismissed. If the UI would show the same copy as an existing failure,
reuse that one.

## Gotchas

- `kind` is a hand-written string, not `runtimeType.toString()`:
  minification reduces `runtimeType` to a letter in release builds.
- `failure.message` is for logs only. Never show it to users.
- `UnknownFailure` keeps `error` and `stackTrace`; report from there.
- Never `rethrow`, never `throw` in a repository or data source.
- Do not catch inside the repository to "add context": wrap at the data
  source (`guard`) or add a typed failure.
- Per-endpoint timeout: override `requestTimeout` in the data source.

## Testing

Fake the `ApiClient`, throw an `ApiException`, assert the `Result`:

```dart
test('maps 401 to AuthFailure', () async {
  when(() => api.get(any())).thenThrow(const ApiResponseException(statusCode: 401));
  final result = await dataSource.fetchProfile();
  expect(result.exceptionOrNull(), isA<AuthFailure>());
});
```

## Review checklist

- [ ] No `try/catch` or `throw` in repositories or data sources (outside `guard`)
- [ ] Every repository/data-source method returns `AsyncResult<…>`
- [ ] No `package:result_dart` import in feature code
- [ ] Models are converted to entities before leaving the repository
- [ ] UI strings come from l10n by failure type, not from `failure.message`
- [ ] New failure types are sealed subclasses with a literal `kind`
