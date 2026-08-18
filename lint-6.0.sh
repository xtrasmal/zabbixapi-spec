#!/usr/bin/env bash
# lint-6.0.sh — house-rules / convention checker for the Zabbix 6.0 API JSON Schema corpus.
#
# Sibling of lint-7.0.sh (which owns the 7.0 tree). This one is scoped to schemas/6.0/
# and is aware of the versioned 3-level layout: schemas/6.0/<object>/<object>.<method>.json.
#
# This does NOT validate JSON Schema itself. Spectral owns that, independently:
#   spectral lint 'schemas/6.0/**/*.json'   (see .spectral.yaml)
# The two checks do not overlap — Spectral says the files are valid JSON Schema;
# this says they follow the repo's 6.0 conventions.
#
# Runs, over every schemas/6.0/<object>/<object>.<method>.json:
#   1. repo conventions: $schema / $id (6.0) / title / $comment (6.0 Source),
#      additionalProperties, delete-array shape           (jq: lint/rules-6.0.jq)
#   2. filename <-> directory <-> title/$id agreement
#   3. zabbix-6.0.json index sync + count guard          (python; self-disables until finalization)
#   4. no stray non-.json files under schemas/6.0/
#
# Usage : ./lint-6.0.sh [--quiet|-q]
# Exit  : 0 clean, 1 lint failures, 2 missing dependency.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_DIR="$ROOT/schemas/6.0"
RULES="$ROOT/lint/rules-6.0.jq"
INDEX="$ROOT/schemas/zabbix-6.0.json"

# Regression guard for the 6.0 API snapshot — a fixed snapshot of the Zabbix 6.0 API.
# Bump these only when a schema is intentionally added or removed.
EXPECT_OBJECTS=53
EXPECT_METHODS=193

quiet=0
[[ "${1:-}" == "--quiet" || "${1:-}" == "-q" ]] && quiet=1

if [[ -t 1 ]]; then
  RED=$'\033[31m'; GRN=$'\033[32m'; DIM=$'\033[2m'; RST=$'\033[0m'
else
  RED=; GRN=; DIM=; RST=
fi
say()       { [[ $quiet -eq 1 ]] || printf '%s\n' "$*"; }
fail_line() { printf '%s%s%s\n' "$RED" "$*" "$RST"; }

# ---- dependencies -----------------------------------------------------------
command -v jq      >/dev/null 2>&1 || { fail_line "FATAL: jq not found"; exit 2; }
command -v python3 >/dev/null 2>&1 || { fail_line "FATAL: python3 not found"; exit 2; }
[[ -f "$RULES" ]] || { fail_line "FATAL: rules file missing: $RULES"; exit 2; }
[[ -d "$SCHEMA_DIR" ]] || { fail_line "FATAL: schema dir missing: $SCHEMA_DIR"; exit 2; }

errors=0

# ---- 1 + 2: per-file conventions + naming -----------------------------------
say "${DIM}== per-file conventions (6.0) ==${RST}"
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

# ---- 4: stray files ---------------------------------------------------------
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  fail_line "[stray] ${f#"$ROOT"/}: non-.json file under schemas/6.0/"; errors=$((errors+1))
done < <(find "$SCHEMA_DIR" -type f ! -name '*.json')

# ---- 3: zabbix-6.0.json index sync + counts --------------------------------
# Hard problems print plain (counted as errors). Soft notes print "WARN ..." (shown, not counted).
say "${DIM}== zabbix-6.0.json index + counts ==${RST}"
idx_out="$(python3 - "$ROOT" "$EXPECT_OBJECTS" "$EXPECT_METHODS" "$INDEX" <<'PY'
import sys, os, glob, json
root, exp_obj, exp_meth, index = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
disk = {}
for f in glob.glob(root + "/schemas/6.0/*/*.json"):
    o = os.path.basename(os.path.dirname(f)); m = os.path.basename(f)[:-5]
    disk.setdefault(o, {})[m] = os.path.relpath(f, root)
nfiles = sum(len(v) for v in disk.values()); nobj = len(disk)

if os.path.exists(index):
    try:
        idx = json.load(open(index))
    except Exception as e:
        print(f"[index] cannot read zabbix-6.0.json: {e}")
    else:
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
        if idx.get("method_count") != nfiles:
            print(f"[index] method_count {idx.get('method_count')} != {nfiles} files on disk")
        if idx.get("object_count") != nobj:
            print(f"[index] object_count {idx.get('object_count')} != {nobj} dirs on disk")
else:
    print("WARN [index] zabbix-6.0.json not present yet (generated at finalization) — index sync skipped")

if nobj != exp_obj:
    if nobj < exp_obj:
        print(f"WARN [count] {nobj}/{exp_obj} objects present — corpus incomplete (remaining waves pending)")
    else:
        print(f"[count] {nobj} objects != expected {exp_obj} (update EXPECT_OBJECTS in lint-6.0.sh if intentional)")
if exp_meth == 0:
    print(f"WARN [count] method-count guard unset (current: {nfiles} files); set EXPECT_METHODS at finalization")
elif nfiles != exp_meth:
    print(f"[count] {nfiles} methods != expected {exp_meth} (update EXPECT_METHODS in lint-6.0.sh if intentional)")

for o in sorted(disk):
    if not disk[o]:
        print(f"[count] object '{o}' has 0 schema files")
PY
)"
if [[ -n "$idx_out" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" == WARN\ * ]]; then
      say "${DIM}${line#WARN }${RST}"
    else
      fail_line "$line"; errors=$((errors+1))
    fi
  done <<< "$idx_out"
fi

# ---- summary ----------------------------------------------------------------
nfiles="$(find "$SCHEMA_DIR" -name '*.json' | wc -l | tr -d ' ')"
nobj="$(find "$SCHEMA_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
if [[ $errors -eq 0 ]]; then
  printf '%sPASS%s  %s schemas across %s objects — 6.0 conventions clean (JSON Schema validity: run spectral)\n' \
    "$GRN" "$RST" "$nfiles" "$nobj"
  exit 0
fi
printf '%sFAIL%s  %s problem(s) found\n' "$RED" "$RST" "$errors"
exit 1
