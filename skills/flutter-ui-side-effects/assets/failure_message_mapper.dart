// shared/mixins/failure_message_mapper.dart
import 'package:your_app/core/errors/app_failure.dart';
import 'package:your_app/l10n/l10n.dart';

/// Maps an [AppFailure] to user-facing copy for listener widgets.
///
/// [failureMessageFor] is the shared baseline. A feature with failures of
/// its own matches those first, then falls through to it:
///
///   String _message(AppLocalizations l10n, AppFailure f) => switch (f) {
///     PurchaseNotAllowedFailure() => l10n.purchaseNotAllowed,
///     _ => failureMessageFor(l10n, f),
///   };
mixin FailureMessageMapper {
  String failureMessage(AppLocalizations l10n, AppFailure failure) =>
      failureMessageFor(l10n, failure);
}

/// Copy is keyed on the failure TYPE, never on `failure.message`, which is
/// for logs and may contain server text or stack details.
String failureMessageFor(AppLocalizations l10n, AppFailure failure) {
  return switch (failure) {
    NetworkFailure() => l10n.errorNetwork,
    AuthFailure() => l10n.errorSessionExpired,
    // A cancelled flow is an answer, not a fault. Callers should skip it
    // before reaching for copy; the empty string is a safety net.
    CancelledFailure() => '',
    // Deliberately no `_` arm here if you want the compiler to force every
    // new failure type to be given copy. Keep it if you prefer a default.
    ServerFailure() ||
    ValidationFailure() ||
    CacheFailure() ||
    UnknownFailure() => l10n.errorGeneric,
  };
}
