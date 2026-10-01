---
name: flutter-feature-scaffold
description: Use when adding a new feature or module to a Flutter app that follows feature-first Clean Architecture (data / domain / presentation) with Riverpod 3 and no code generation for providers, when deciding which layer or folder a file belongs in, or when reviewing dependency direction between layers. Provides the folder layout, per-layer rules, barrel conventions, build order and a scaffold script.
---

# Feature-first Clean Architecture for Flutter

## Layout

```text
lib/
├── app/            bootstrap, root widget, environment
├── core/           cross-cutting contracts + adapters (network, analytics,
│                   error_tracking, storage, errors, config, logging…)
├── shared/         reusable UI & utils with no business meaning
│                   (routing, theme, widgets, extensions)
├── features/       one folder per business capability
└── l10n/

features/<feature>/
├── <feature>.dart            barrel: exports domain, di, presentation (NOT data)
├── data/                     no Riverpod, no Flutter widgets
│   ├── datasources/          <x>_remote_data_source.dart, <x>_endpoints.dart
│   ├── models/               JSON-aware classes (fromJson / toEntity)
│   └── repositories/         <x>_repository_impl.dart
├── di/
│   └── <feature>_providers.dart   dataSource + repository providers
├── domain/
│   ├── entities/             immutable value classes (Equatable)
│   ├── repositories/         abstract interface class contracts
│   ├── services/             pure domain logic spanning entities
│   └── usecases/             only when logic is shared or non-trivial
└── presentation/
    ├── pages/
    ├── widgets/              includes <Feature>Listeners (side effects)
    ├── providers/            Notifier / AsyncNotifier / FutureProvider
    └── state/                state classes when a notifier needs more than a value
```

Every folder has a barrel named after it (`entities.dart`,
`datasources.dart`, …) that exports its files. Import barrels, not files,
across folders.

## Dependency direction

```text
presentation ──▶ di ──▶ data
      │           │       │
      └──────▶ domain ◀───┘
```

- **Domain** imports nothing from Flutter, Dio, Firebase, Riverpod or any
  platform SDK. Plain Dart + `equatable`.
- **Data** implements domain contracts. It is the only layer that knows JSON,
  endpoints and the `ApiClient`. It does **not** import Riverpod: wiring is
  not its job, so it stays testable in plain Dart.
- **`di/`** is the composition point: the only place that sees `data/` and
  `domain/` together. It builds the data source and repository and exposes
  the repository as its **contract** type (`Provider<FavoriteRepository>`).
- **Presentation** imports `domain/` and `di/`, **never `data/`**. It does not
  call an `ApiClient`, parse JSON or touch SDKs.
- Between features, depend on the other feature's **domain** (or `di/`) only.
  If two features need the same model, promote it to `core/` instead of
  reaching into another feature's `data/` or `presentation/`.

Why `di/` and not "a provider next to the impl": a provider in `data/` forces
presentation to import `data/` just to `ref.watch` it, and the rule
"presentation never imports data" gains an exception that people stretch
(first the provider, then "just this one model"). A dedicated file keeps the
rule absolute, so a script can check it. It also keeps `data/` free of
Riverpod.

Call chain: `Widget → (Async)Notifier → Repository contract → RepositoryImpl
→ RemoteDataSource → ApiClient`. Never skip a layer.

## Per-layer rules

**Entities** — immutable, `extends Equatable`, `const` constructor, no JSON.
Drop wire-only fields (`userId` the client already knows) in `toEntity`.
`Equatable` also makes `ref.watch(p.select(...))` work by value.

**Repository contract** — `abstract interface class`, methods return
`AsyncResult<Entity>` / `AsyncResult<Unit>` (see `flutter-result-errors`).
Signatures use entities and value objects, never models or SDK types.

**Models** — live only in `data/models/`. Factory `fromJson` (via
`json_serializable`), `toEntity()`, and `fromEntity` when the model is sent
back. Entities never import models. Models never leave the repository.

**Endpoints** — one `abstract final class <X>Endpoints` of path constants and
path-building static methods, so URLs are not string literals in data sources.

**Remote data source** — `abstract interface class` + `Impl` that
`with RemoteDataSourceGuard`, takes an `ApiClient`, returns `AsyncResult<Model>`.
No provider in this file.

**Repository impl** — takes the data source, converts models → entities with
`result.map(...)`, passes failures through. No provider in this file.

**`di/<feature>_providers.dart`** — the providers for the two above:

```dart
final favoriteRemoteDataSourceProvider = Provider<FavoriteRemoteDataSource>(
  (ref) => FavoriteRemoteDataSourceImpl(ref.watch(apiClientProvider)),
);

/// Exposes the CONTRACT, never the implementation. Tests override this.
final favoriteRepositoryProvider = Provider<FavoriteRepository>(
  (ref) => FavoriteRepositoryImpl(ref.watch(favoriteRemoteDataSourceProvider)),
);
```

In a test, override the contract and `data/` is never touched:

```dart
ProviderContainer(overrides: [
  favoriteRepositoryProvider.overrideWithValue(FakeFavoriteRepository()),
]);
```

**Providers (presentation)** — one responsibility each. Pick by role:

| Need | Use |
|---|---|
| Immutable dependency (repo, service, client) | `Provider` |
| Async read-only data | `FutureProvider` |
| Continuous stream (auth state, connectivity) | `StreamProvider` |
| Mutable sync state (filters, selected tab) | `NotifierProvider` |
| Mutable async state (a screen's store, a session) | `AsyncNotifierProvider` |
| One user action in flight | `SubmissionNotifier` + `autoDispose` |

Declare providers explicitly. No `riverpod_generator`, no `@riverpod`, no
`StateNotifier`. Business rules that belong in the domain do not live in
providers.

**Pages and widgets** — no JSON, no SDKs, no business rules. Side effects
(navigation, snackbars, analytics) are declared with `ref.listen` in a
`<Feature>Listeners` widget with a `child` parameter that wraps the page;
widgets only `watch` declarative state.

## Build order for a new feature

1. Entity (`domain/entities`)
2. Repository contract (`domain/repositories`)
3. Model with `toEntity` (`data/models`) — then `dart run build_runner build`
4. Endpoints class (`data/datasources`)
5. Remote data source
6. Repository impl
7. `di/` providers (data source + repository, exposed as the contract)
8. Presentation provider (`AsyncNotifier` whose `build` reads the repository
   through `di/` and calls `getOrThrow()`)
9. Submission notifier for each user action
10. `<Feature>Listeners` widget
11. Page + widgets, registered in the router
12. Tests: data source with a fake `ApiClient`, repository mapping, notifier
    with the repository contract overridden, widget test with fakes
13. Run `scripts/check_boundaries.sh`

## Scaffold script

`scripts/scaffold_feature.sh` creates steps 1–8 as compilable stubs with all
barrels, and never overwrites existing files:

```bash
# from the Flutter project root
bash <path-to-skill>/scripts/scaffold_feature.sh favorites --entity Favorite
```

- First argument: feature folder name, `snake_case`.
- `--entity Name`: PascalCase entity (default: the feature name in PascalCase).
- `--package name`: override the package name (default: read from `pubspec.yaml`).

Afterwards: add fields to the entity and model, fill the endpoints, run
`dart run build_runner build` and `dart fix --apply` (the stubs' import order
is not lint-sorted), then continue from step 9.

## Checking the boundaries

`scripts/check_boundaries.sh` is plain `grep`, so it needs no Dart toolchain
and fits in any CI step. Run it from the project root:

```bash
bash <path-to-skill>/scripts/check_boundaries.sh        # default: lib/features
```

It exits 1 and lists every violation of these rules, or prints `OK`:

1. `presentation/` never imports `data/`
2. `domain/` imports no framework or SDK, nor `data/`, `presentation/`, `di/`
3. `data/` imports neither `presentation/`, `di/` nor Riverpod
4. A feature never imports another feature's `data/` or `presentation/`
5. Feature code imports no third-party SDK directly

Run it after every scaffold, and in CI so the boundary cannot erode.

## Review checklist

- [ ] `check_boundaries.sh` prints `OK`
- [ ] `domain/` has no imports from `flutter`, `dio`, `flutter_riverpod`, SDKs
- [ ] `di/` exposes the repository as its contract type, not the `Impl`
- [ ] Repositories return entities, not models; no thrown exceptions
- [ ] Each folder has a barrel; cross-folder imports use barrels
- [ ] Providers are explicit (no codegen) and each has one job
- [ ] Side effects live in the feature's `Listeners` widget
