#!/usr/bin/env bash
# Scaffold a feature-first Clean Architecture feature
# (data / domain / di / presentation).
#
# Usage (from the Flutter project root):
#   bash scaffold_feature.sh <feature_snake_case> [--entity PascalName] [--package pkg_name]
#
# Creates compilable stubs and barrels under lib/features/<feature>/.
# Never overwrites an existing file.
#
# Assumes the project already has (see the sibling skills):
#   lib/core/errors/errors.dart                      (flutter-result-errors)
#   lib/core/network/api_client.dart                 (flutter-sdk-contracts)
#   lib/core/network/remote_data_source_guard.dart   (flutter-result-errors)
#   lib/core/network/network_providers.dart          (exposes `apiClientProvider`)
#
# Then run `check_boundaries.sh` (same folder) to verify the layer rules.
set -euo pipefail

usage() {
  echo "Usage: $0 <feature_snake_case> [--entity PascalName] [--package pkg_name]" >&2
  exit 1
}

[ $# -ge 1 ] || usage
FEATURE="$1"
shift
ENTITY=""
PKG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --entity) ENTITY="${2:-}"; shift 2 ;;
    --package) PKG="${2:-}"; shift 2 ;;
    *) usage ;;
  esac
done

if ! [[ "$FEATURE" =~ ^[a-z][a-z0-9_]*$ ]]; then
  echo "error: feature must be snake_case (got '$FEATURE')" >&2
  exit 1
fi

if [ ! -f pubspec.yaml ] || [ ! -d lib ]; then
  echo "error: run from the Flutter project root (pubspec.yaml and lib/ not found)" >&2
  exit 1
fi

if [ -z "$PKG" ]; then
  PKG="$(sed -n 's/^name:[[:space:]]*//p' pubspec.yaml | head -1 | tr -d '\r')"
fi
[ -n "$PKG" ] || { echo "error: could not read package name from pubspec.yaml" >&2; exit 1; }

if [ -z "$ENTITY" ]; then
  ENTITY="$(printf '%s' "$FEATURE" | awk -F_ '{for(i=1;i<=NF;i++) printf "%s%s", toupper(substr($i,1,1)), substr($i,2)}')"
fi
if ! [[ "$ENTITY" =~ ^[A-Z][A-Za-z0-9]*$ ]]; then
  echo "error: --entity must be PascalCase (got '$ENTITY')" >&2
  exit 1
fi

SNAKE="$(printf '%s' "$ENTITY" | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' | tr '[:upper:]' '[:lower:]')"
CAMEL="$(printf '%s' "${ENTITY:0:1}" | tr '[:upper:]' '[:lower:]')${ENTITY:1}"

ROOT="lib/features/$FEATURE"
CREATED=()
SKIPPED=()

# Replaces the __PLACEHOLDERS__ in stdin (used for both paths and contents).
substitute() {
  sed \
    -e "s|__PKG__|$PKG|g" \
    -e "s|__FEATURE__|$FEATURE|g" \
    -e "s|__E__|$ENTITY|g" \
    -e "s|__s__|$SNAKE|g" \
    -e "s|__e__|$CAMEL|g"
}

# write_file <relative path under feature root>  (content on stdin, with placeholders)
write_file() {
  local target
  target="$ROOT/$(printf '%s' "$1" | substitute)"
  mkdir -p "$(dirname "$target")"
  if [ -e "$target" ]; then
    SKIPPED+=("$target")
    cat >/dev/null
    return
  fi
  substitute >"$target"
  CREATED+=("$target")
}

keep_dir() {
  mkdir -p "$ROOT/$1"
  [ -e "$ROOT/$1/.gitkeep" ] || touch "$ROOT/$1/.gitkeep"
}

# ---------------------------------------------------------------- barrels
# The public surface of a feature: domain, its providers, its UI.
# `data/` is deliberately NOT exported: other features must not reach it.
write_file "$FEATURE.dart" <<'EOF'
export 'di/di.dart';
export 'domain/domain.dart';
export 'presentation/presentation.dart';
EOF

write_file "di/di.dart" <<'EOF'
export '__s___providers.dart';
EOF

write_file "domain/domain.dart" <<'EOF'
export 'entities/entities.dart';
export 'repositories/repositories.dart';
EOF

write_file "domain/entities/entities.dart" <<'EOF'
export '__s__.dart';
EOF

write_file "domain/repositories/repositories.dart" <<'EOF'
export '__s___repository.dart';
EOF

write_file "data/data.dart" <<'EOF'
export 'datasources/datasources.dart';
export 'models/models.dart';
export 'repositories/repositories.dart';
EOF

write_file "data/datasources/datasources.dart" <<'EOF'
export '__s___endpoints.dart';
export '__s___remote_data_source.dart';
EOF

write_file "data/models/models.dart" <<'EOF'
export '__s___model.dart';
EOF

write_file "data/repositories/repositories.dart" <<'EOF'
export '__s___repository_impl.dart';
EOF

write_file "presentation/presentation.dart" <<'EOF'
export 'providers/providers.dart';
// Add 'pages/pages.dart' and 'widgets/widgets.dart' once those folders have files.
EOF

write_file "presentation/providers/providers.dart" <<'EOF'
export '__s___provider.dart';
EOF

# ---------------------------------------------------------------- domain
write_file "domain/entities/__s__.dart" <<'EOF'
import 'package:equatable/equatable.dart';

/// TODO: describe what a __E__ is in the domain.
///
/// Immutable and compared by value. No JSON here: that belongs to the model.
class __E__ extends Equatable {
  const __E__({required this.id});

  final String id;

  @override
  List<Object?> get props => [id];
}
EOF

write_file "domain/repositories/__s___repository.dart" <<'EOF'
import 'package:__PKG__/core/errors/errors.dart';
import 'package:__PKG__/features/__FEATURE__/domain/entities/entities.dart';

/// Business capabilities of the __FEATURE__ feature.
///
/// Returns entities, never models. Failures are values (`AppFailure`).
abstract interface class __E__Repository {
  AsyncResult<List<__E__>> getAll();
}
EOF

keep_dir "domain/services"
keep_dir "domain/usecases"

# ---------------------------------------------------------------- data
write_file "data/models/__s___model.dart" <<'EOF'
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:__PKG__/features/__FEATURE__/domain/entities/entities.dart';

part '__s___model.g.dart';

/// Wire representation of a [__E__]. Knows JSON; the entity does not.
@JsonSerializable()
class __E__Model extends Equatable {
  const __E__Model({required this.id});

  factory __E__Model.fromJson(Map<String, dynamic> json) =>
      _$__E__ModelFromJson(json);

  final String id;

  Map<String, dynamic> toJson() => _$__E__ModelToJson(this);

  /// Drop wire-only fields here.
  __E__ toEntity() => __E__(id: id);

  @override
  List<Object?> get props => [id];
}
EOF

write_file "data/datasources/__s___endpoints.dart" <<'EOF'
abstract final class __E__Endpoints {
  static const String _base = '/__FEATURE__';

  static const String list = _base;
}
EOF

write_file "data/datasources/__s___remote_data_source.dart" <<'EOF'
import 'package:__PKG__/core/errors/errors.dart';
import 'package:__PKG__/core/network/api_client.dart';
import 'package:__PKG__/core/network/remote_data_source_guard.dart';
import 'package:__PKG__/features/__FEATURE__/data/datasources/__s___endpoints.dart';
import 'package:__PKG__/features/__FEATURE__/data/models/models.dart';

abstract interface class __E__RemoteDataSource {
  AsyncResult<List<__E__Model>> getAll();
}

class __E__RemoteDataSourceImpl
    with RemoteDataSourceGuard
    implements __E__RemoteDataSource {
  __E__RemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  AsyncResult<List<__E__Model>> getAll() {
    return guard(() async {
      final response = await _apiClient.get(__E__Endpoints.list);
      // TODO: adapt to your API envelope.
      final data = response['data'] as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;
      return items
          .map((json) => __E__Model.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }
}
// No Riverpod here: wiring lives in di/.
EOF

write_file "data/repositories/__s___repository_impl.dart" <<'EOF'
import 'package:__PKG__/core/errors/errors.dart';
import 'package:__PKG__/features/__FEATURE__/data/datasources/datasources.dart';
import 'package:__PKG__/features/__FEATURE__/domain/domain.dart';

class __E__RepositoryImpl implements __E__Repository {
  __E__RepositoryImpl(this._remote);

  final __E__RemoteDataSource _remote;

  @override
  AsyncResult<List<__E__>> getAll() async {
    final result = await _remote.getAll();
    // Models become entities here, before leaving the repository.
    return result.map((models) => models.map((m) => m.toEntity()).toList());
  }
}
// No Riverpod here: wiring lives in di/.
EOF

# ---------------------------------------------------------------- di
# The only place that sees data/ and domain/ together. Presentation imports
# this file, never data/.
write_file "di/__s___providers.dart" <<'EOF'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:__PKG__/core/network/network_providers.dart';
import 'package:__PKG__/features/__FEATURE__/data/datasources/datasources.dart';
import 'package:__PKG__/features/__FEATURE__/data/repositories/repositories.dart';
import 'package:__PKG__/features/__FEATURE__/domain/domain.dart';

final __e__RemoteDataSourceProvider = Provider<__E__RemoteDataSource>(
  (ref) => __E__RemoteDataSourceImpl(ref.watch(apiClientProvider)),
);

/// Exposes the CONTRACT, never the implementation. Tests override this.
final __e__RepositoryProvider = Provider<__E__Repository>(
  (ref) => __E__RepositoryImpl(ref.watch(__e__RemoteDataSourceProvider)),
);
EOF

# ---------------------------------------------------------------- presentation
write_file "presentation/providers/__s___provider.dart" <<'EOF'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:__PKG__/features/__FEATURE__/di/di.dart';
import 'package:__PKG__/features/__FEATURE__/domain/domain.dart';

/// Store for the __FEATURE__ screen.
///
/// `getOrThrow()` is the one sanctioned throw: it surfaces the `AppFailure`
/// as an `AsyncError` for the UI.
class __E__Notifier extends AsyncNotifier<List<__E__>> {
  @override
  Future<List<__E__>> build() async {
    final result = await ref.watch(__e__RepositoryProvider).getAll();
    return result.getOrThrow();
  }
}

final __e__Provider = AsyncNotifierProvider<__E__Notifier, List<__E__>>(
  __E__Notifier.new,
);
EOF

keep_dir "presentation/pages"
keep_dir "presentation/widgets"
keep_dir "presentation/state"

# ---------------------------------------------------------------- report
echo "Feature '$FEATURE' (entity $ENTITY, package $PKG)"
echo "Created ${#CREATED[@]} file(s):"
for f in "${CREATED[@]}"; do echo "  + $f"; done
if [ ${#SKIPPED[@]} -gt 0 ]; then
  echo "Skipped ${#SKIPPED[@]} existing file(s):"
  for f in "${SKIPPED[@]}"; do echo "  = $f"; done
fi
echo
echo "Next: add fields to the entity and model, fill the endpoints,"
echo "run 'dart run build_runner build' and 'dart fix --apply', then add a submission notifier,"
echo "the <Feature>Listeners widget and the page."
