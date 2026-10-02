#!/usr/bin/env bash
# Smoke test for the repo: skill metadata, no project-specific leaks, and the
# two scripts of flutter-feature-scaffold (positive and negative cases).
#
#   bash tests/smoke_test.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAFFOLD="$REPO/skills/flutter-feature-scaffold/scripts/scaffold_feature.sh"
CHECK="$REPO/skills/flutter-feature-scaffold/scripts/check_boundaries.sh"
FAILED=0

pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; FAILED=$((FAILED + 1)); }

echo "== skill metadata"
for dir in "$REPO"/skills/*/; do
  name="$(basename "$dir")"
  if python3 - "$dir/SKILL.md" "$name" <<'EOF'
import re, sys
path, name = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
m = re.match(r"^---\nname: (.+)\ndescription: (.+)\n---\n", text)
assert m, "missing or malformed frontmatter"
assert m.group(1) == name, f"name '{m.group(1)}' != folder '{name}'"
assert len(m.group(2)) <= 1024, "description over 1024 chars"
EOF
  then pass "$name frontmatter"; else fail "$name frontmatter"; fi
done

echo "== manifests are valid JSON"
for f in "$REPO"/.claude-plugin/*.json; do
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" \
    && pass "$(basename "$f")" || fail "$(basename "$f")"
done

echo "== no project-specific names in skills"
if grep -rnE "[Ww]ordhabit|WordHabit|\bWh[A-Z][a-z]+|TodayWord" "$REPO/skills" "$REPO/README.md"; then
  fail "project-specific name found"
else
  pass "no leaks"
fi

echo "== every referenced skill and asset exists"
missing=0
for s in $(grep -rhoE '`flutter-[a-z0-9-]+`' "$REPO/skills" "$REPO/README.md" | tr -d '`' | sort -u); do
  [ -d "$REPO/skills/$s" ] || { echo "     missing skill: $s"; missing=1; }
done
for a in $(grep -rhoE 'assets/[a-z_]+\.dart' "$REPO/skills" | sort -u); do
  [ -n "$(find "$REPO/skills" -path "*$a" | head -1)" ] || { echo "     missing asset: $a"; missing=1; }
done
[ "$missing" -eq 0 ] && pass "references resolve" || fail "dangling references"

echo "== scaffold + boundary checker"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP" && mkdir lib && printf 'name: demo_app\n' > pubspec.yaml

bash "$SCAFFOLD" favorites --entity Favorite >/dev/null && pass "scaffold favorites" || fail "scaffold favorites"
bash "$SCAFFOLD" orders --entity Order >/dev/null && pass "scaffold orders" || fail "scaffold orders"
[ -f lib/features/favorites/di/favorite_providers.dart ] && pass "di/ generated" || fail "di/ missing"

# data/ must not contain Riverpod in the generated stubs
if grep -rq "flutter_riverpod" lib/features/favorites/data; then fail "stubs: data/ imports Riverpod"; else pass "stubs: data/ is Riverpod-free"; fi

# a second run must not overwrite
echo "// edited" >> lib/features/favorites/domain/entities/favorite.dart
bash "$SCAFFOLD" favorites --entity Favorite >/dev/null
tail -1 lib/features/favorites/domain/entities/favorite.dart | grep -q "// edited" \
  && pass "scaffold never overwrites" || fail "scaffold overwrote a file"
sed -i.bak '$d' lib/features/favorites/domain/entities/favorite.dart && rm -f lib/features/favorites/domain/entities/favorite.dart.bak

bash "$CHECK" >/dev/null && pass "checker: clean scaffold is OK" || fail "checker: clean scaffold flagged"

# Inject one violation per rule; the checker must report all of them.
f=lib/features/favorites
o=lib/features/orders
echo "import 'package:demo_app/features/favorites/data/models/models.dart';" >> $f/presentation/providers/favorite_provider.dart
echo "import 'package:flutter/material.dart';" >> $f/domain/entities/favorite.dart
echo "import 'package:flutter_riverpod/flutter_riverpod.dart';" >> $f/data/repositories/favorite_repository_impl.dart
echo "import 'package:demo_app/features/favorites/data/data.dart';" >> $o/domain/entities/order.dart
echo "import 'package:dio/dio.dart';" >> $o/presentation/providers/order_provider.dart
# A legitimate cross-feature import (another feature's domain) must NOT be flagged.
echo "import 'package:demo_app/features/favorites/domain/domain.dart';" >> $o/presentation/providers/order_provider.dart

out="$(bash "$CHECK" 2>&1)"; code=$?
[ "$code" -eq 1 ] && pass "checker exits 1 on violations" || fail "checker exit code $code"
for rule in "presentation/ imports data/" "domain/ imports a framework" "data/ imports Riverpod" "another feature's data/" "imports an SDK directly"; do
  echo "$out" | grep -q "$rule" && pass "detects: $rule" || fail "missed: $rule"
done
echo "$out" | grep -q "order_provider.dart:[0-9]*:import 'package:demo_app/features/favorites/domain" \
  && fail "flagged a legitimate cross-feature domain import" || pass "allows cross-feature domain imports"

echo
if [ "$FAILED" -eq 0 ]; then echo "All checks passed."; else echo "$FAILED check(s) failed."; exit 1; fi
