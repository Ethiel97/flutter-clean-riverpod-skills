// core/analytics/analytics_event.dart

/// Closed analytics vocabulary: features construct one of these instead
/// of passing arbitrary names or property maps to the SDK.
///
/// Why closed: free-form `track('btn_clk', {...})` calls drift into
/// inconsistent names and high-cardinality properties. A sealed class
/// makes the full list of events greppable and reviewable in one place.
sealed class AnalyticsEvent {
  const AnalyticsEvent();

  String get name;

  /// Low-cardinality values only. Never a token, never an email.
  Map<String, Object> get properties;
}

enum AuthEventKind { signedUp, signedIn, signedOut }

final class AuthCompletedEvent extends AnalyticsEvent {
  const AuthCompletedEvent(this.kind, {this.provider});

  final AuthEventKind kind;

  /// Which sign-in method was used; one aggregate rate hides per-provider
  /// problems.
  final String? provider;

  @override
  String get name => switch (kind) {
    AuthEventKind.signedUp => 'account signed up',
    AuthEventKind.signedIn => 'account signed in',
    AuthEventKind.signedOut => 'account signed out',
  };

  @override
  Map<String, Object> get properties => {'provider': ?provider};
}
