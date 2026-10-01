---
name: flutter-ui-side-effects
description: Use when a Flutter widget needs navigation, snackbars, dialogs, analytics or any one-shot reaction to a state change, when button callbacks contain context.router / ScaffoldMessenger / analytics calls, when error copy must be shown for a failed action, or when adding a <Feature>Listeners widget. Covers ref.listen listener widgets, per-attempt submission state and mapping failures to user-facing text.
---

# UI side effects with listener widgets

Side effects (navigation, snackbars, dialogs, analytics) are **never
performed inline in button callbacks** or scattered through widgets. They are
declared with `ref.listen`, grouped in one **listener widget per feature**
placed near the page root.

## Why

- **One place to read.** "What happens after sign-in?" has one answer, not six
  `onPressed` handlers.
- **Reacts to the real outcome.** A callback that navigates right after
  `submit()` runs before the request has succeeded. A listener fires when the
  state actually becomes success or error.
- **No rebuilds.** The widget listens without watching and returns `child`
  untouched, so it never rebuilds the page beneath it.
- **Testable.** A listener test mounts only the listener, overrides providers,
  drives state and asserts on a recording fake (see `flutter-testing`).

## The pattern

Template: `assets/feature_listeners.dart`.

```dart
class ItemsListeners extends ConsumerWidget with FailureMessageMapper {
  const ItemsListeners({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(itemSubmissionProvider, (previous, next) {
      switch (next) {
        case AsyncData(value: final result?):   // success
          ...
        case AsyncError(error: final AppFailure failure):  // failure
          AppSnackBar.show(context, message: failureMessage(context.l10n, failure));
        default:
          break;
      }
    });
    return child;
  }
}
```

Pages wrap their `Scaffold`:

```dart
return ItemsListeners(child: Scaffold(...));
```

## Rules

1. **One listener widget per feature**, `<Feature>Listeners`, under
   `features/<feature>/presentation/widgets/`.
2. **Each effect listens to the state it semantically follows.** Navigation
   follows the *session*; error copy follows the *attempt*; analytics follow
   whichever state they measure. Do not hang everything off one provider.
3. **`ref.listen`, not `ref.watch`**, inside the listener widget, and return
   `child` unchanged.
4. **Transient action state lives in its own `autoDispose` provider**
   (`AsyncValue<T?>`, idle = `AsyncData(null)`), never in the app-wide session
   provider and never in `setState`. Use `SubmissionNotifier` from
   `flutter-result-errors`.
5. **Widgets read the same provider for declarative state**
   (`submission.isLoading` drives a button's `loading` flag); the listener owns
   the imperative reactions.
6. **User feedback goes through your design-system wrapper** (`AppSnackBar`),
   never raw `SnackBar`s sprinkled around.
7. **Copy comes from l10n keyed on the failure type** via a
   `FailureMessageMapper`, not from `failure.message`.
   Template: `assets/failure_message_mapper.dart`.
8. **Listeners react; they do not decide.** Business rules stay in the domain
   or the notifier. A listener that grows `if` ladders about business state is a
   missing domain method.

## Reading an `AsyncValue` in a listener

Pattern-match, most specific first:

```dart
switch (next) {
  case AsyncData(value: final result?):                      // success
    ...
  case AsyncError(error: final AppFailure f) when isInline(f): // shown by the form
    break;
  case AsyncError(error: final AppFailure f):                // everything else
    ...
  default:                                                   // idle / loading
    break;
}
```

Skip failures another widget already presents (field validation) and
`CancelledFailure` (the user backed out; staying silent is the right UX).

## Reacting to changes, not emissions

A listener can fire for a rebuild that changed nothing relevant. Compare
`previous` and `next`:

```dart
ref.listen(itemsProvider, (previous, next) {
  final topic = next.value?.topic;
  if (topic == null || topic == previous?.value?.topic) return;  // no change
  ref.read(analyticsServiceProvider).track(ItemsFilteredEvent(topic: topic));
});
```

## Gotchas

- **A widget above the router has no `context.router`.** A global listener in
  `MaterialApp.builder` must reach the router through a provider
  (`ref.read(appRouterProvider)`), not through `context`.
- **Two listeners racing for the navigation stack.** If a session listener and a
  setup listener can both navigate on the same change, make one stand aside
  explicitly and write down why.
- **After an `await`, check `context.mounted`** before using `context`.
- **Order inside one widget is declaration order.** Do not rely on it between
  listener widgets.
- **`ref.listen` does not fire for the initial value** (unless
  `fireImmediately: true`). Use that deliberately, rarely.
- **Do not `ref.watch` inside the listener** to read a value you need in the
  callback; use `ref.read` in the callback.

## Review checklist

- [ ] No `Navigator`, `context.router`, `ScaffoldMessenger` or analytics call in an `onPressed`
- [ ] One `<Feature>Listeners` per feature, wrapping the page, returning `child`
- [ ] Each `ref.listen` follows the state its effect depends on
- [ ] Action state is an `autoDispose` submission provider, not session state or `setState`
- [ ] Error copy keyed on failure type through the mapper, shown via the design-system snackbar
- [ ] `CancelledFailure` and inline-handled failures stay silent
- [ ] Repeated emissions are de-duplicated by comparing `previous` and `next`
