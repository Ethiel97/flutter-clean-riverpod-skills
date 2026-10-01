// features/<feature>/presentation/widgets/<feature>_listeners.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:your_app/core/analytics/analytics.dart';
import 'package:your_app/core/errors/errors.dart';
import 'package:your_app/features/items/presentation/providers/providers.dart';
import 'package:your_app/shared/mixins/failure_message_mapper.dart';
import 'package:your_app/shared/widgets/app_snack_bar.dart'; // YOUR design-system wrapper

/// Every UI side effect of the items feature, in one place.
///
/// - Listens, never watches: [child] is returned untouched, so this widget
///   causes no rebuilds.
/// - Each effect follows the state it semantically depends on: copy for a
///   failed attempt follows the attempt; analytics follow the state they
///   measure.
/// - Wrap the page's Scaffold with it.
class ItemsListeners extends ConsumerWidget with FailureMessageMapper {
  const ItemsListeners({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      ..listen(itemSubmissionProvider, (previous, next) {
        switch (next) {
          // Success → measure it.
          case AsyncData(value: final mutation?):
            ref
                .read(analyticsServiceProvider)
                .track(ItemChangedEvent(removed: mutation.removed));

          // A failure the form already shows inline: stay quiet.
          case AsyncError(error: final ValidationFailure _):
            break;

          // Any other failure → copy keyed on the failure TYPE.
          case AsyncError(error: final AppFailure failure):
            AppSnackBar.show(
              context,
              message: failureMessage(context.l10n, failure),
              variant: SnackBarVariant.error,
            );

          // Idle and loading: nothing to do.
          default:
            break;
        }
      })
      ..listen(itemsProvider, (previous, next) {
        // React to a *change*, not to every emission: compare previous/next
        // so a rebuild with the same filter does not fire twice.
        final topic = next.value?.topic;
        if (topic == null || topic == previous?.value?.topic) return;
        ref.read(analyticsServiceProvider).track(ItemsFilteredEvent(topic: topic));
      });

    return child;
  }
}

// Usage:
//
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final submitting = ref.watch(
//       itemSubmissionProvider.select((s) => s.isLoading),
//     );
//     return ItemsListeners(
//       child: Scaffold(
//         body: ...,
//         floatingActionButton: FloatingActionButton(
//           // Declarative state drives the button; the listener owns the
//           // imperative reactions (snackbar, analytics, navigation).
//           onPressed: submitting ? null : ref.read(itemSubmissionProvider.notifier).add,
//         ),
//       ),
//     );
//   }
