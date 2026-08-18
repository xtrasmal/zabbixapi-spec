#!/usr/bin/env bash
# lint.sh — lint one version's API method schemas.
#
# Judges each schema on its own: house conventions (jq: lint/rules.jq) plus
# JSON Schema draft-2020-12 validity (Spectral: .spectral.yaml). Version-agnostic —
# the version is read from the path. No baseline, no expected counts, nothing to diff.
#
# Usage : ./lint.sh <path under schemas/<version>>
#         ./lint.sh schemas/6.0            # a whole version
#         ./lint.sh schemas/6.0/host       # one object
# Exit  : 0 clean, 1 lint failures, 2 missing dependency.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES="$ROOT/lint/rules.jq"

target="${1:?usage: lint.sh <path under schemas/<version>>}"
[[ "$target" = /* ]] || target="$ROOT/$target"
rel="${target#"$ROOT"/}"
version="$(printf '%s\n' "$rel" | sed -E 's#^schemas/([^/]+).*#\1#')"

command -v jq       >/dev/null 2>&1 || { echo "FATAL: jq not found" >&2; exit 2; }
command -v spectral >/dev/null 2>&1 || { echo "FATAL: spectral not found" >&2; exit 2; }
[[ -f "$RULES" ]] || { echo "FATAL: rules file missing: $RULES" >&2; exit 2; }
[[ -e "$target" ]] || { echo "FATAL: target missing: $target" >&2; exit 2; }
[[ -n "$version" && "$version" != "$rel" ]] || { echo "FATAL: cannot read <version> from '$rel' (expected schemas/<version>/...)" >&2; exit 2; }

if [[ -t 1 ]]; then RED=$'\033[31m'; GRN=$'\033[32m'; RST=$'\033[0m'; else RED=; GRN=; RST=; fi

errors=0

# ---- house conventions (jq) -------------------------------------------------
while IFS= read -r f; do
  relf="${f#"$ROOT"/}"
  base="$(basename "$f" .json)"          # object.method
  dir="$(basename "$(dirname "$f")")"    # object
  object="${base%%.*}"
  method="${base#*.}"

  if [[ "$base" != *.* ]]; then
    printf '%s[naming] %s: filename is not <object>.<method>.json%s\n' "$RED" "$relf" "$RST"; errors=$((errors+1)); continue
  fi
  if [[ "$object" != "$dir" ]]; then
    printf '%s[naming] %s: prefix %s != directory %s%s\n' "$RED" "$relf" "$object" "$dir" "$RST"; errors=$((errors+1))
  fi
  if ! jq -e . "$f" >/dev/null 2>&1; then
    printf '%s[json] %s: not parseable JSON%s\n' "$RED" "$relf" "$RST"; errors=$((errors+1)); continue
  fi
  while IFS= read -r msg; do
    [[ -z "$msg" ]] && continue
    printf '%s[convention] %s: %s%s\n' "$RED" "$relf" "$msg" "$RST"; errors=$((errors+1))
  done < <(jq -r --arg version "$version" --arg object "$object" --arg method "$method" -f "$RULES" "$f")
done < <(find "$target" -name '*.json' | sort)

# ---- JSON Schema validity (Spectral) ---------------------------------------
if [[ -d "$target" ]]; then sp_target="$target/**/*.json"; else sp_target="$target"; fi
sp_out="$(spectral lint --ruleset "$ROOT/.spectral.yaml" "$sp_target" 2>&1)"; sp_rc=$?
if [[ $sp_rc -ne 0 ]]; then
  printf '%s\n' "$sp_out"
  errors=$((errors+1))
fi

# ---- summary ----------------------------------------------------------------
nfiles="$(find "$target" -name '*.json' | wc -l | tr -d ' ')"
if [[ $errors -eq 0 ]]; then
  printf '%sPASS%s  %s schema(s) under %s — conventions + JSON Schema validity clean\n' "$GRN" "$RST" "$nfiles" "$rel"
  exit 0
fi
printf '%sFAIL%s  %s problem(s)\n' "$RED" "$RST" "$errors"
exit 1
