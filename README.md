# flutter-clean-riverpod-skills

Agent skills for Flutter apps built with **feature-first Clean Architecture**,
**Riverpod 3 (no code generation)**, **Result-based error handling** and
**every SDK behind an application-owned contract**.

They are extracted from a production Flutter app and encode the rules that
kept it consistent over time, with the *why* next to each rule so an agent
(and you) can apply them with judgment rather than by rote.

Works with Claude Code and any agent that reads `SKILL.md` folders.

## Opinionated by design

These skills assume a specific stack. If yours differs, they will fight you.

| Concern | Choice |
|---|---|
| Architecture | Feature-first Clean Architecture, ports & adapters |
| State / DI | `flutter_riverpod` 3, explicit providers, **no** `riverpod_generator` / `@riverpod`, no `StateNotifier`, no GetIt |
| Errors | `result_dart` behind app-owned `Result` / `AsyncResult` typedefs, sealed `AppFailure` |
| HTTP | `dio` behind an app-owned `ApiClient` |
| Models | `json_serializable` + `equatable` |

Not using Riverpod? `flutter-result-errors` and `flutter-sdk-contracts` still
apply almost unchanged; `flutter-feature-scaffold` does not.

## Skills

| Skill | Use it when |
|---|---|
| [`flutter-feature-scaffold`](skills/flutter-feature-scaffold) | Adding a feature, deciding where a file belongs, reviewing layer dependencies. Includes a scaffold script. |
| [`flutter-result-errors`](skills/flutter-result-errors) | Writing data sources, repositories or providers that can fail. Sealed `AppFailure`, one catch boundary, how UI folds failures. |
| [`flutter-sdk-contracts`](skills/flutter-sdk-contracts) | Touching Firebase, Sentry, PostHog, Dio, storage or any plugin. Contracts, adapters, no-ops, recording fakes. |

Each skill ships copy-ready Dart under `assets/`. Replace `your_app` with your
package name.

## Install

### Claude Code plugin

```text
/plugin marketplace add <owner>/flutter-clean-riverpod-skills
/plugin install flutter-clean-riverpod-skills@flutter-clean-riverpod-skills
```

### Copy the skills

```bash
# per project
cp -r skills/* your_project/.claude/skills/

# or for every project
cp -r skills/* ~/.claude/skills/
```

## Try the scaffold script

```bash
cd your_flutter_project
bash path/to/skills/flutter-feature-scaffold/scripts/scaffold_feature.sh favorites --entity Favorite
```

It generates the data / domain / presentation stubs and barrels, and never
overwrites existing files.

## Recommended `pubspec.yaml` dependencies

```yaml
dependencies:
  flutter_riverpod: ^3.0.0
  result_dart: ^2.0.0
  dio: ^5.0.0
  equatable: ^2.0.0
  json_annotation: ^4.9.0

dev_dependencies:
  json_serializable: ^6.8.0
  build_runner: ^2.4.0
  mocktail: ^1.0.0
```

Pin to the versions your project already uses.

## Contributing

Issues and PRs welcome. A skill should stay small, state *why* for every rule,
and be checked against a real task: run the same prompt with and without the
skill and keep it only if the output improves.

## License

MIT
