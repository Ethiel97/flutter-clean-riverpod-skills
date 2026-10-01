---
name: flutter-sdk-contracts
description: Use when adding, replacing or touching any third-party SDK or platform plugin in a Flutter app (Firebase, Sentry, PostHog, Dio, secure storage, shared_preferences, notifications, share, clipboard, permissions, purchases), or when feature code imports an SDK directly. Defines application-owned contracts (ports), adapters, no-op/composite/recording implementations and their Riverpod wiring.
---

# SDKs behind application-owned contracts

> Every dependency that crosses the application boundary is wrapped behind
> a contract the application owns. Feature code depends on contracts, never
> on SDKs.

## Why

- **Replaceable.** Vendors change (PostHog → Amplitude, Sentry → Crashlytics).
  When only one adapter file imports the SDK, a migration touches one file.
- **Testable.** Tests override a provider with a fake; no platform channel,
  no `MissingPluginException`, no SDK initialisation in widget tests.
- **Narrow.** The contract exposes what the app *needs* (`track(event)`),
  not the SDK's whole surface, so features cannot misuse it.

## The recipe

For a capability `Foo` (analytics, error tracking, clipboard, storage…):

1. **Contract** — `abstract interface class FooService` in `core/foo/`.
   Only app-owned types in its signatures. Document *why* on the methods
   whose behaviour is surprising.
2. **App-owned vocabulary** — if the SDK takes free-form input, close it:
   a `sealed class AnalyticsEvent` instead of `track(String, Map)`.
3. **Adapter** — `FirebaseFooService implements FooService`. The only file
   that imports the SDK. It translates SDK errors into `AppFailure`
   (see `flutter-result-errors`) or swallows them if the contract says
   "never throws".
4. **No-op** — `NoOpFooService` for tests and disabled builds.
5. **Provider** — expose the contract, never the adapter:
   ```dart
   final fooServiceProvider = Provider<FooService>((ref) {
     final config = ref.watch(fooConfigProvider);
     return config.isEnabled ? SdkFooService(config) : const NoOpFooService();
   });
   ```
6. **Test double** — a recording fake in `test/helpers/` (see
   `assets/recording_analytics_service.dart`). Prefer recording fakes to
   mocks: assertions read as "this event was tracked".

Naming: `<Capability>Service`. Adapter: `<Vendor><Capability>Service`.

## Contract design rules

- **No SDK types** in parameters, return types or thrown exceptions.
- **Fallible → `AsyncResult<Unit>`** (or a typed value). **Fire-and-forget
  reporting → `Future<void>` that never throws**: reporting a failure must
  not fail the operation that caused it (`ErrorTrackingService`).
- **Low-cardinality payloads.** Never put tokens or emails in tags,
  properties or breadcrumbs.
- Keep one capability per contract. Do not make an `AnalyticsAndCrash` god
  interface.

## Config and wiring

- A required config provider throws until overridden at the composition
  root, so a missing override fails loudly at startup:
  ```dart
  final networkConfigProvider = Provider<NetworkConfig>(
    (ref) => throw UnimplementedError('override in bootstrap'),
  );
  ```
- An optional capability defaults to **disabled** (`AnalyticsConfig.disabled()`)
  so widget and provider tests never initialise a platform SDK. Bootstrap
  overrides it for real runs.
- Feature code never calls `Firebase…instance`, `Sentry.captureException`
  or `Dio()`. Only adapters and provider files do.

## Several destinations, one contract

When the same event must reach several vendors, compose behind the same
contract (`assets/composite_analytics_service.dart`). Rules: call **every**
destination even after one fails, and return the **first** failure so
partial delivery stays visible. The provider picks 0 / 1 / many with a
`switch` on the list length; features never learn the count.

## The HTTP boundary (worked example)

`assets/api_client.dart`, `dio_api_client.dart` and the `ApiException`
hierarchy (from `flutter-result-errors`) are the reference implementation:

- `ApiClient` speaks decoded JSON maps and throws only `ApiException`s.
- `DioApiClient` is the only file allowed to know Dio's API; it maps
  `DioException` types to `ApiConnectionException` / `ApiResponseException` /
  `ApiUnknownException`.
- Remote data sources depend on `ApiClient` and run through `guard(...)`.

Interceptor order matters when you build the `Dio` in a provider:

- Put the **logger before the auth interceptor**, so request headers are
  logged before the `Authorization` header is attached and tokens never hit
  the console. Enable it in debug builds only.
- Put the **breadcrumb/error-reporting interceptor last**, so a 401 that the
  refresh interceptor is about to retry successfully reads as one line.
- Use a **second Dio with no interceptors** for the token-refresh call.
  Refreshing through the main client re-enters the refresh interceptor, and
  since it is queued the nested call waits behind the very request it should
  unblock.

## Verifying the boundary

Run from the project root; each should print nothing:

```bash
# SDKs must not be imported by feature code
grep -rnE "package:(dio|firebase_[a-z_]+|sentry[a-z_]*|posthog_flutter|purchases_flutter|shared_preferences|flutter_secure_storage)/" lib/features

# Static singletons must not be reached from features
grep -rnE "(Firebase[A-Za-z]*\.instance|Sentry\.capture|SharedPreferences\.getInstance|Dio\()" lib/features
```

Adapters under `lib/core/` and the provider files that construct them are
the only legitimate importers. Tune the package list to your pubspec.

## Review checklist

- [ ] New SDK import appears in exactly one adapter file
- [ ] Contract signatures contain no SDK types
- [ ] A `NoOp` and a recording fake exist
- [ ] Provider returns the contract type (`Provider<FooService>`), not the adapter
- [ ] Optional capability defaults to disabled; required config throws until overridden
- [ ] Nothing sensitive goes into tags, properties or breadcrumbs
