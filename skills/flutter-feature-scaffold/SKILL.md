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
├── <feature>.dart            barrel: exports data, domain, presentation
├── data/
│   ├── datasources/          <x>_remote_data_source.dart, <x>_endpoints.dart
│   ├── models/               JSON-aware classes (fromJson / toEntity)
│   └── repositories/         <x>_repository_impl.dart
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
presentation ──▶ domain ◀── data
```

- **Domain** imports nothing from Flutter, Dio, Firebase, Riverpod or any
  platform SDK. Plain Dart + `equatable`.
- **Data** implements domain contracts. It is the only layer that knows JSON,
  endpoints and the `ApiClient`.
- **Presentation** talks to repositories (or use cases) through domain
  contracts and never calls an `ApiClient`, parses JSON or touches SDKs.
  The one allowed reach into `data/` is importing the **repository provider**
  (declared beside the impl, typed as the contract) to `ref.watch` it. Never
  import models, data sources or endpoints from presentation.
- Between features, depend on the other feature's **domain** only. If two
  features need the same model, promote it to `core/` or a shared domain
  module instead of reaching into another feature's `data/`.

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
Its provider sits at the bottom of the file.

**Repository impl** — takes the data source, converts models → entities with
`result.map(...)`, passes failures through. Its provider sits at the bottom
of the file and returns the **contract** type.

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
5. Remote data source + provider
6. Repository impl + provider
7. Presentation provider (`AsyncNotifier` whose `build` reads the repository
   and calls `getOrThrow()`)
8. Submission notifier for each user action
9. `<Feature>Listeners` widget
10. Page + widgets, registered in the router
11. Tests: data source with a fake `ApiClient`, repository mapping, notifier
    with overridden providers, widget test with fakes

## Scaffold script

`scripts/scaffold_feature.sh` creates steps 1–7 as compilable stubs with all
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
is not lint-sorted), then continue from step 8.

## Review checklist

- [ ] `domain/` has no imports from `flutter`, `dio`, `flutter_riverpod`, SDKs
- [ ] Presentation imports from `data/` only the repository provider (no models, data sources, endpoints)
- [ ] Repositories return entities, not models; no thrown exceptions
- [ ] Each folder has a barrel; cross-folder imports use barrels
- [ ] Providers are explicit (no codegen) and each has one job
- [ ] Side effects live in the feature's `Listeners` widget
