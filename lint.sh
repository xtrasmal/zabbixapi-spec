#!/usr/bin/env bash
# lint.sh — the official linter for the Zabbix 7.0 API JSON Schema corpus.
#
# Runs, over every schemas/<object>/<object>.<method>.json:
#   1. draft 2020-12 meta-schema conformance             (python jsonschema)
#   2. repo conventions: $schema / $id / title / $comment,
#      additionalProperties, delete-array shape           (jq: lint/rules.jq)
#   3. filename <-> directory <-> title/$id agreement
#   4. methods.json index is in sync with the files on disk (python)
#   5. no stray non-.json files under schemas/
#   6. object/method count regression guard
#
# Usage : ./lint.sh [--quiet|-q]
# Exit  : 0 clean, 1 lint failures, 2 missing dependency.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_DIR="$ROOT/schemas"
RULES="$ROOT/lint/rules.jq"

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
python3 -c 'import jsonschema' 2>/dev/null \
  || { fail_line "FATAL: python module 'jsonschema' not installed (pip install jsonschema)"; exit 2; }
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
  fail_line "[stray] ${f#"$ROOT"/}: non-.json file under schemas/"; errors=$((errors+1))
done < <(find "$SCHEMA_DIR" -type f ! -name '*.json')

# ---- 1: meta-schema conformance ---------------------------------------------
say "${DIM}== draft 2020-12 meta-schema ==${RST}"
meta_out="$(python3 - "$SCHEMA_DIR" <<'PY'
import sys, glob, json
from jsonschema import Draft202012Validator
for f in sorted(glob.glob(sys.argv[1] + "/**/*.json", recursive=True)):
    try:
        Draft202012Validator.check_schema(json.load(open(f)))
    except Exception as e:
        print(f"[metaschema] {f}: {str(e).splitlines()[0][:160]}")
PY
)"
if [[ -n "$meta_out" ]]; then
  fail_line "$meta_out"; errors=$((errors + $(count_lines "$meta_out")))
fi

# ---- 4 + 6: methods.json sync + counts --------------------------------------
say "${DIM}== methods.json index + counts ==${RST}"
idx_out="$(python3 - "$ROOT" "$EXPECT_OBJECTS" "$EXPECT_METHODS" <<'PY'
import sys, os, glob, json
root, exp_obj, exp_meth = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
disk = {}
for f in glob.glob(root + "/schemas/*/*.json"):
    o = os.path.basename(os.path.dirname(f)); m = os.path.basename(f)[:-5]
    disk.setdefault(o, {})[m] = os.path.relpath(f, root)
try:
    idx = json.load(open(root + "/methods.json"))
except Exception as e:
    print(f"[index] cannot read methods.json: {e}"); sys.exit()
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
    print(f"[count] {nobj} objects != expected {exp_obj} (update EXPECT_OBJECTS in lint.sh if intentional)")
if nfiles != exp_meth:
    print(f"[count] {nfiles} methods != expected {exp_meth} (update EXPECT_METHODS in lint.sh if intentional)")
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
  printf '%sPASS%s  %s schemas across %s objects — meta-schema, conventions, and index all clean\n' \
    "$GRN" "$RST" "$nfiles" "$nobj"
  exit 0
fi
printf '%sFAIL%s  %s problem(s) found\n' "$RED" "$RST" "$errors"
exit 1
