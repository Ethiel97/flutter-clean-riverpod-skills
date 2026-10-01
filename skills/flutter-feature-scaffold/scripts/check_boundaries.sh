#!/usr/bin/env bash
# Verify the layer boundaries of a feature-first Clean Architecture project.
#
# Usage (from the Flutter project root):
#   bash check_boundaries.sh [features_dir]      # default: lib/features
#
# Exits 1 and lists every violation, or prints OK. Plain grep: no Dart
# toolchain needed, so it runs in any CI step.
#
# Rules:
#   1. presentation/ never imports data/
#   2. domain/ imports no framework or SDK, and nothing from data/ or presentation/
#   3. data/ does not import presentation/ or Riverpod (wiring lives in di/)
#   4. a feature never imports another feature's data/ or presentation/
#   5. feature code imports no third-party SDK directly (adapters live in core/)
set -uo pipefail
shopt -s nullglob

FEATURES="${1:-lib/features}"
[ -d "$FEATURES" ] || { echo "error: '$FEATURES' not found (run from the project root)" >&2; exit 2; }

VIOLATIONS=0

# report <rule label> <grep output>
report() {
  if [ -n "$2" ]; then
    echo "x $1"
    echo "$2" | sed 's/^/    /'
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
}

# scan <extended regex> <dir...>  -> matching import/export lines with file:line
scan() {
  local pattern="$1"
  shift
  [ $# -gt 0 ] || return 0
  grep -rnE --include='*.dart' "^(import|export) .*($pattern)" "$@" 2>/dev/null \
    | grep -v '\.g\.dart:' || true
}

PRESENTATION=("$FEATURES"/*/presentation)
DOMAIN=("$FEATURES"/*/domain)
DATA=("$FEATURES"/*/data)

# 1. presentation -> data (package imports and relative imports)
report "presentation/ imports data/ (go through di/ instead)" \
  "$(scan "features/[a-z0-9_]+/data/|\.\./data/|'data/" "${PRESENTATION[@]}")"

# 2. domain purity
SDKS='flutter|flutter_riverpod|riverpod|dio|firebase_[a-z_]+|sentry[a-z_]*|posthog_flutter|purchases_flutter|shared_preferences|flutter_secure_storage|json_annotation'
report "domain/ imports a framework or SDK (domain must be pure Dart)" \
  "$(scan "package:($SDKS)/" "${DOMAIN[@]}")"
report "domain/ imports data/ or presentation/" \
  "$(scan "features/[a-z0-9_]+/(data|presentation|di)/|\.\./(data|presentation|di)/" "${DOMAIN[@]}")"

# 3. data -> presentation / riverpod
report "data/ imports presentation/ or di/" \
  "$(scan "features/[a-z0-9_]+/(presentation|di)/|\.\./(presentation|di)/" "${DATA[@]}")"
report "data/ imports Riverpod (move providers to di/)" \
  "$(scan "package:(flutter_riverpod|riverpod)/" "${DATA[@]}")"

# 4. cross-feature reach into data/ or presentation/
cross=""
for dir in "$FEATURES"/*/; do
  name="$(basename "$dir")"
  # Drop imports of the feature's own layers. Compare against the import
  # text only: the "file:line:" prefix always contains the feature's name.
  hits="$(scan "features/[a-z0-9_]+/(data|presentation)/" "$dir" \
    | awk -v own="features/$name/" '{ rest=$0; sub(/^[^:]*:[0-9]+:/, "", rest); if (index(rest, own) == 0) print }')"
  [ -n "$hits" ] && cross="${cross}${hits}"$'\n'
done
report "a feature imports another feature's data/ or presentation/ (use its domain/ or barrel)" "${cross%$'\n'}"

# 5. SDKs in feature code (data/ may use json_annotation for models)
ALL_FEATURE_DIRS=("$FEATURES"/*)
report "feature code imports an SDK directly (wrap it in a core/ contract)" \
  "$(scan "package:(dio|firebase_[a-z_]+|sentry[a-z_]*|posthog_flutter|purchases_flutter|shared_preferences|flutter_secure_storage)/" "${ALL_FEATURE_DIRS[@]}")"

if [ "$VIOLATIONS" -eq 0 ]; then
  echo "OK: no boundary violations in $FEATURES"
  exit 0
fi
echo
echo "$VIOLATIONS rule(s) violated."
exit 1
