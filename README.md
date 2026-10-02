# flutter-clean-riverpod-skills

[![Validate](https://github.com/Ethiel97/flutter-clean-riverpod-skills/actions/workflows/validate.yml/badge.svg)](https://github.com/Ethiel97/flutter-clean-riverpod-skills/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Agent skills for Flutter apps built with **feature-first Clean Architecture**,
**Riverpod 3 (no code generation)**, **Result-based error handling** and
**every SDK behind an application-owned contract**.

They are extracted from a production Flutter app and encode the rules that kept
it consistent over time, with the *why* next to every rule, so an agent (and you)
can apply them with judgment instead of by rote. Each skill also ships
copy-ready Dart and, where it helps, a script.

- [What you get](#what-you-get)
- [Is this for you?](#is-this-for-you)
- [Install](#install)
- [Verify the install](#verify-the-install)
- [Use it](#use-it)
- [Set up your project](#set-up-your-project)
- [Enforce the architecture in CI](#enforce-the-architecture-in-ci)
- [Update and uninstall](#update-and-uninstall)
- [Repository layout](#repository-layout)
- [Contributing](#contributing)

## What you get

| Skill | Use it when |
|---|---|
| [`flutter-feature-scaffold`](skills/flutter-feature-scaffold) | Adding a feature, deciding where a file belongs, reviewing layer dependencies. Includes a **scaffold script** and a **boundary checker**. |
| [`flutter-result-errors`](skills/flutter-result-errors) | Writing data sources, repositories or providers that can fail. Sealed `AppFailure`, one catch boundary, how the UI folds failures. |
| [`flutter-sdk-contracts`](skills/flutter-sdk-contracts) | Touching Firebase, Sentry, PostHog, Dio, storage or any plugin. Contracts, adapters, no-ops, recording fakes. |
| [`flutter-riverpod3`](skills/flutter-riverpod3) | Choosing provider types, writing notifiers, `watch` / `read` / `listen` / `select`, disposal, `ref.mounted`, Riverpod 3's automatic retry. |
| [`flutter-ui-side-effects`](skills/flutter-ui-side-effects) | Navigation, snackbars, dialogs or analytics reacting to state. `<Feature>Listeners` widgets, submission state, failure-to-copy mapping. |
| [`flutter-testing`](skills/flutter-testing) | Testing data sources, notifiers, widgets, listeners and goldens through contract overrides; mock vs fake. |

The skills reference each other (for example `flutter-testing` points to the
recording fakes in `flutter-sdk-contracts`), so **install the whole set**.

The one rule worth remembering:

```text
presentation ──▶ di ──▶ data
      │           │       │
      └──────▶ domain ◀───┘
```

Presentation never imports `data/`. A per-feature `di/` file wires the repository
and exposes its **contract**, so `data/` stays free of Riverpod and the rule has
no exceptions to erode.

## Is this for you?

These skills are **opinionated**. If your stack differs, they will fight you.

| Concern | Choice |
|---|---|
| Architecture | Feature-first Clean Architecture, ports and adapters |
| State / DI | `flutter_riverpod` 3, explicit providers. **No** `riverpod_generator` / `@riverpod`, no `StateNotifier`, no GetIt |
| Errors | `result_dart` behind app-owned `Result` / `AsyncResult` typedefs, sealed `AppFailure` |
| HTTP | `dio` behind an app-owned `ApiClient` |
| Models | `json_serializable` + `equatable` |

Not using Riverpod? `flutter-result-errors` and `flutter-sdk-contracts` still
apply almost unchanged; the other four do not. Using Bloc? This is not the right
pack.

## Install

Pick **one** of the methods below.

### A. Claude Code plugin (recommended)

In Claude Code, add this repository as a marketplace, then install the plugin:

```text
/plugin marketplace add Ethiel97/flutter-clean-riverpod-skills
/plugin install flutter-clean-riverpod-skills@flutter-clean-riverpod-skills
```

All six skills are installed together and are available in every project.

### B. Copy the skills into your project (shared with your team)

Skills live in a `.claude/skills/` folder. Committing it means everyone who
clones the project gets them.

```bash
git clone https://github.com/Ethiel97/flutter-clean-riverpod-skills.git /tmp/fcrs

# from the root of your Flutter project
mkdir -p .claude/skills
cp -R /tmp/fcrs/skills/* .claude/skills/
```

### C. Copy the skills for yourself (all your projects)

```bash
git clone https://github.com/Ethiel97/flutter-clean-riverpod-skills.git /tmp/fcrs

mkdir -p ~/.claude/skills
cp -R /tmp/fcrs/skills/* ~/.claude/skills/
```

### D. Other agents and Claude.ai

- **Any agent that reads `SKILL.md` folders:** copy the folders under `skills/` to
  the directory your agent loads skills from. Each skill is a self-contained
  folder with a `SKILL.md`.
- **Claude.ai:** zip a single skill folder (for example `skills/flutter-riverpod3`)
  and upload it from the skills section of the settings. Availability depends on
  your plan, and you have to upload each skill separately.

## Verify the install

1. Start a new Claude Code session in your Flutter project.
2. Ask: *"Which skills do you have for Flutter architecture?"* The six
   `flutter-*` skills should be listed.
3. Try a task that should trigger one, for example: *"Add a favorites feature
   with an API call"*. The agent should follow the layout and the `di/` rule from
   `flutter-feature-scaffold`.

Skills load **automatically** when a task matches their description. In recent
versions of Claude Code you can also invoke one by name, for example
`/flutter-feature-scaffold`.

## Use it

Example prompts that trigger the skills:

| You say | Skill that kicks in |
|---|---|
| "Create a `favorites` feature" | `flutter-feature-scaffold` |
| "Why does my repository throw? Make it return a Result" | `flutter-result-errors` |
| "Add PostHog analytics" | `flutter-sdk-contracts` |
| "Should this be a `Notifier` or an `AsyncNotifier`?" | `flutter-riverpod3` |
| "Show a snackbar when saving fails" | `flutter-ui-side-effects` |
| "Write tests for this notifier" | `flutter-testing` |

### Scaffold a feature

```bash
# from the root of your Flutter project
bash .claude/skills/flutter-feature-scaffold/scripts/scaffold_feature.sh favorites --entity Favorite
```

It creates the data / domain / `di` / presentation stubs and every barrel, reads
your package name from `pubspec.yaml`, and **never overwrites an existing file**.
Then run `dart run build_runner build` and `dart fix --apply`.

## Set up your project

The skills teach the *patterns*; copy the foundation files once.

**1. Add the dependencies** (pin to the versions you already use):

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

**2. Copy the foundation Dart files** from the skills' `assets/` folders and
replace `your_app` with your package name (the name in `pubspec.yaml`):

| From | To |
|---|---|
| `flutter-result-errors/assets/app_failure.dart`, `result.dart`, `errors.dart` | `lib/core/errors/` |
| `flutter-result-errors/assets/api_exception.dart`, `remote_data_source_guard.dart` | `lib/core/network/` |
| `flutter-result-errors/assets/submission_notifier.dart` | `lib/core/utils/` |
| `flutter-sdk-contracts/assets/api_client.dart`, `dio_api_client.dart` | `lib/core/network/` |
| `flutter-riverpod3/assets/retry_policy.dart` | `lib/core/utils/` |
| `flutter-testing/assets/test_container.dart`, `pump_app.dart` | `test/helpers/` |

Or simply ask the agent: *"Set up the foundation files from the Flutter skills
in this project."*

**3. Point your agent at the skills.** Add a short note to your `CLAUDE.md` (or
`AGENTS.md`) so the rules are applied by default:

```markdown
## Architecture
This project follows feature-first Clean Architecture with Riverpod 3 (no codegen).
Use the flutter-* skills for features, errors, SDK wrappers, providers, UI side
effects and tests. Presentation never imports data/; wiring lives in each
feature's di/ folder.
```

## Enforce the architecture in CI

`check_boundaries.sh` is plain `grep`: no Dart toolchain, fast, and it fails the
build when a layer rule is broken. It checks that presentation never imports
`data/`, domain stays pure Dart, `data/` has no Riverpod, features do not reach
into each other's `data/` or `presentation/`, and feature code imports no SDK.

```bash
bash .claude/skills/flutter-feature-scaffold/scripts/check_boundaries.sh   # default: lib/features
```

GitHub Actions example:

```yaml
- name: Check architecture boundaries
  run: bash .claude/skills/flutter-feature-scaffold/scripts/check_boundaries.sh
```

If you installed the plugin (method A) rather than copying the skills into the
project, vendor the script instead: copy it to `tool/check_boundaries.sh` and run
that.

## Update and uninstall

| Method | Update | Uninstall |
|---|---|---|
| A. Plugin | `/plugin marketplace update flutter-clean-riverpod-skills` | `/plugin uninstall flutter-clean-riverpod-skills@flutter-clean-riverpod-skills` |
| B / C. Copied | Pull the repo again and re-run the `cp -R` (it overwrites the skills) | Delete the `flutter-*` folders from `.claude/skills/` or `~/.claude/skills/` |

If you edited a copied skill, diff before overwriting.

## Repository layout

```text
.claude-plugin/        plugin.json, marketplace.json
skills/
├── flutter-feature-scaffold/   SKILL.md, scripts/ (scaffold + boundary checker)
├── flutter-result-errors/      SKILL.md, assets/
├── flutter-sdk-contracts/      SKILL.md, assets/
├── flutter-riverpod3/          SKILL.md, assets/
├── flutter-ui-side-effects/    SKILL.md, assets/
└── flutter-testing/            SKILL.md, assets/
tests/smoke_test.sh    validates metadata, references and both scripts (run by CI)
```

Run the checks locally with `bash tests/smoke_test.sh`.

## Contributing

Issues and pull requests are welcome. A skill should stay small, state **why**
for every rule, and be checked against a real task: run the same prompt with and
without the skill, and keep the skill only if the output improves. Run
`bash tests/smoke_test.sh` before opening a pull request.

## License

[MIT](LICENSE)
