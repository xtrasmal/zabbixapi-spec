#!/usr/bin/env bash
# lint-7.0.sh — house-rules / convention checker for the Zabbix 7.0 API JSON Schema corpus.
#
# This does NOT validate JSON Schema itself. Spectral owns that, independently:
#   spectral lint 'schemas/7.0/**/*.json'   (see .spectral.yaml)
# The two checks do not overlap — Spectral says the files are valid JSON Schema;
# this says they follow the repo's conventions.
#
# Runs, over every schemas/7.0/<object>/<object>.<method>.json:
#   1. repo conventions: $schema / $id / title / $comment,
#      additionalProperties, delete-array shape           (jq: lint/rules-7.0.jq)
#   2. filename <-> directory <-> title/$id agreement
#   3. zabbix-7.0.json index is in sync with the files on disk (python)
#   4. no stray non-.json files under schemas/7.0/
#   5. object/method count regression guard
#
# Usage : ./lint-7.0.sh [--quiet|-q]
# Exit  : 0 clean, 1 lint failures, 2 missing dependency.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_DIR="$ROOT/schemas/7.0"
RULES="$ROOT/lint/rules-7.0.jq"

# Regression guard — this repo is a fixed snapshot of the Zabbix 7.0 API.
# Bump these only when a schema is intentionally added or removed.
EXPECT_OBJECTS=58
EXPECT_METHODS=222

quiet=0
[[ "${1:-}" == "--quiet" || "${1:-}" == "-q" ]] && quiet=1

if [[ -t 1 ]]; then
  RED=$'\033[31m'; GRN=$'\033[32m'; DIM=$'\033[2m'; RST=$'\033[0m'
else
  RED=; GRN=; DIM=; RST=
fi
say()       { [[ $quiet -eq 1 ]] || printf '%s\n' "$*"; }
fail_line() { printf '%s%s%s\n' "$RED" "$*" "$RST"; }
count_lines() { printf '%s\n' "$1" | grep -c '.'; }

# ---- dependencies -----------------------------------------------------------
command -v jq      >/dev/null 2>&1 || { fail_line "FATAL: jq not found"; exit 2; }
command -v python3 >/dev/null 2>&1 || { fail_line "FATAL: python3 not found"; exit 2; }
[[ -f "$RULES" ]] || { fail_line "FATAL: rules file missing: $RULES"; exit 2; }

errors=0

# ---- 2 + 3: per-file conventions + naming -----------------------------------
say "${DIM}== per-file conventions ==${RST}"
while IFS= read -r f; do
  rel="${f#"$ROOT"/}"
  base="$(basename "$f" .json)"          # object.method
  dir="$(basename "$(dirname "$f")")"    # object
  object="${base%%.*}"
  method="${base#*.}"

  if [[ "$base" != *.* ]]; then
    fail_line "[naming] $rel: filename is not <object>.<method>.json"; errors=$((errors+1)); continue
  fi
  if [[ "$object" != "$dir" ]]; then
    fail_line "[naming] $rel: filename prefix '$object' != directory '$dir'"; errors=$((errors+1))
  fi
  if ! jq -e . "$f" >/dev/null 2>&1; then
    fail_line "[json] $rel: not parseable JSON"; errors=$((errors+1)); continue
  fi
  while IFS= read -r msg; do
    [[ -z "$msg" ]] && continue
    fail_line "[convention] $rel: $msg"; errors=$((errors+1))
  done < <(jq -r --arg object "$object" --arg method "$method" -f "$RULES" "$f")
done < <(find "$SCHEMA_DIR" -name '*.json' | sort)

# ---- 5: stray files ---------------------------------------------------------
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  fail_line "[stray] ${f#"$ROOT"/}: non-.json file under schemas/7.0/"; errors=$((errors+1))
done < <(find "$SCHEMA_DIR" -type f ! -name '*.json')

# ---- zabbix-7.0.json sync + counts ---------------------------------------------
say "${DIM}== zabbix-7.0.json index + counts ==${RST}"
idx_out="$(python3 - "$ROOT" "$EXPECT_OBJECTS" "$EXPECT_METHODS" <<'PY'
import sys, os, glob, json
root, exp_obj, exp_meth = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
disk = {}
for f in glob.glob(root + "/schemas/7.0/*/*.json"):
    o = os.path.basename(os.path.dirname(f)); m = os.path.basename(f)[:-5]
    disk.setdefault(o, {})[m] = os.path.relpath(f, root)
try:
    idx = json.load(open(root + "/schemas/zabbix-7.0.json"))
except Exception as e:
    print(f"[index] cannot read schemas/zabbix-7.0.json: {e}"); sys.exit()
io = idx.get("objects", {})
if set(io) != set(disk):
    print("[index] object set mismatch: missing", sorted(set(disk) - set(io)),
          "extra", sorted(set(io) - set(disk)))
for o in sorted(set(io) & set(disk)):
    if set(io[o]) != set(disk[o]):
        print(f"[index] {o}: methods missing", sorted(set(disk[o]) - set(io[o])),
              "extra", sorted(set(io[o]) - set(disk[o]))); continue
    for m in io[o]:
        got, want = io[o][m].get("path"), disk[o][m]
        if got != want:
            print(f"[index] {o}.{m}: path '{got}' != '{want}'")
nfiles = sum(len(v) for v in disk.values()); nobj = len(disk)
if idx.get("method_count") != nfiles:
    print(f"[index] method_count {idx.get('method_count')} != {nfiles} files on disk")
if idx.get("object_count") != nobj:
    print(f"[index] object_count {idx.get('object_count')} != {nobj} dirs on disk")
if nobj != exp_obj:
    print(f"[count] {nobj} objects != expected {exp_obj} (update EXPECT_OBJECTS in lint-7.0.sh if intentional)")
if nfiles != exp_meth:
    print(f"[count] {nfiles} methods != expected {exp_meth} (update EXPECT_METHODS in lint-7.0.sh if intentional)")
for o in sorted(disk):
    if not disk[o]:
        print(f"[count] object '{o}' has 0 schema files")
PY
)"
if [[ -n "$idx_out" ]]; then
  fail_line "$idx_out"; errors=$((errors + $(count_lines "$idx_out")))
fi

# ---- summary ----------------------------------------------------------------
nfiles="$(find "$SCHEMA_DIR" -name '*.json' | wc -l | tr -d ' ')"
nobj="$(find "$SCHEMA_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
if [[ $errors -eq 0 ]]; then
  printf '%sPASS%s  %s schemas across %s objects — conventions and index clean (JSON Schema validity: run spectral)\n' \
    "$GRN" "$RST" "$nfiles" "$nobj"
  exit 0
fi
printf '%sFAIL%s  %s problem(s) found\n' "$RED" "$RST" "$errors"
exit 1
