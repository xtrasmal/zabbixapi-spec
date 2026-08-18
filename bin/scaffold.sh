#!/usr/bin/env bash
# scaffold.sh — preflight's deterministic scaffolder.
#
# From this version's manifest (schemas/zabbix-<version>.json), write a skeleton
# schema for every method. Body by method tail:
#   get    -> type:object, commonGetParams inlined as properties, additionalProperties:false
#   delete -> type:array, items:{type:string}, minItems:1
#   else   -> type:object, properties:{}, additionalProperties:false
# Scrape then fills description + method-specific properties. Self-contained:
# reads only this version's manifest; nothing is compared to another version.
#
# Usage: bin/scaffold.sh <version> [object]   # object = scaffold just that one object
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${1:?usage: scaffold.sh <version> [object]}"
only="${2:-}"
manifest="$ROOT/schemas/zabbix-$version.json"

command -v jq >/dev/null 2>&1 || { echo "FATAL: jq not found" >&2; exit 2; }
[[ -f "$manifest" ]] || { echo "FATAL: no manifest schemas/zabbix-$version.json" >&2; exit 1; }

common="$(jq -c '.["$defs"].commonGetParams' "$manifest")"
[[ "$common" != "null" ]] || { echo "FATAL: manifest has no \$defs.commonGetParams" >&2; exit 1; }

count=0
while IFS=$'\t' read -r object M path; do
  [[ -n "$only" && "$object" != "$only" ]] && continue
  tail="${M##*.}"
  id="https://zabbix.com/$version/api/$object/$M"
  src="https://www.zabbix.com/documentation/$version/en/manual/api/reference/$object/$tail"
  out="$ROOT/$path"
  mkdir -p "$(dirname "$out")"
  case "$tail" in
    get)
      jq -n --arg id "$id" --arg t "$M" --arg src "$src" --argjson common "$common" \
        '{"$schema":"https://json-schema.org/draft/2020-12/schema","$id":$id,"title":$t,"description":"","$comment":("Source: "+$src),"type":"object","properties":$common,"additionalProperties":false}' > "$out" ;;
    delete)
      jq -n --arg id "$id" --arg t "$M" --arg src "$src" \
        '{"$schema":"https://json-schema.org/draft/2020-12/schema","$id":$id,"title":$t,"description":"","$comment":("Source: "+$src),"type":"array","items":{"type":"string"},"minItems":1}' > "$out" ;;
    *)
      jq -n --arg id "$id" --arg t "$M" --arg src "$src" \
        '{"$schema":"https://json-schema.org/draft/2020-12/schema","$id":$id,"title":$t,"description":"","$comment":("Source: "+$src),"type":"object","properties":{},"additionalProperties":false}' > "$out" ;;
  esac
  count=$((count+1))
done < <(jq -r '.objects | to_entries[] | .key as $o | .value | to_entries[] | [$o, .key, .value.path] | @tsv' "$manifest")

echo "scaffolded $count file(s) for $version${only:+ (object: $only)}"
