# Zabbix API — JSON Schema Extraction Spec

You produce the JSON Schemas for ONE object of the Zabbix `<version>` API from the official docs.

INPUT: `<version>` (e.g. `6.0`), `<object>` (your assigned object).
NOTATION: `M` = dotted method (e.g. `token.get`); `<method>` = its tail (e.g. `get`).
SOURCE: this version's own rendered docs, loaded with `crw`, one page at a time, paced:
`crw "https://www.zabbix.com/documentation/<version>/en/manual/api/reference/<object>/<method>" -f markdown`
The page opens with the manual's sidebar nav — skip it; your content starts at the `# <object>.<method>` heading (Description, Parameters, the property/parameter tables). Read the actual table rows. Never invent a name, type, or enum value. Cite the docs URL only — never a codebase/source path.

**HARD RULE — SCRAPE 6.0 FROM 6.0, NEVER FROM 7.0.** Your only source is this version's own docs at the `/<version>/` URLs above. Do NOT read, open, copy, template from, or compare against any 7.0 schema (`schemas/7.0/...`) or 7.0 doc — not "to check", not "as a starting point", not "to fill a gap". Diffing 6.0 against 7.0 is exactly what broke the last 6.0 run. This version's page is the sole authority: if it differs from anything you'd expect, the page wins. If a page is missing or unreadable, STOP and report it — never substitute another version.

You CREATE every `schemas/<version>/<object>/M.json` from scratch. Nothing is scaffolded.

## STEPS

1. RUN `jq '.objects["<object>"]' schemas/zabbix-<version>.json` — this is your method list.
2. EXTRACT the doc tables — `crw` each page one at a time, paced (`.../en/manual/api/reference/`):
   - `<object>` — the GROUP PAGE: method list + one-line method descriptions, AND its "Object references" list. That list names every object-definition page for this object — scrape ALL of them, not just `object` (larger objects define several related/nested objects, each on its own def page under the group).
   - `<object>/object` and every other def page the group page references — the property tables (name, type, description, required). The def page's actual content is authoritative: scrape EVERY property-table section present on it, even ones the "Object references" list omits or misnames (the 6.0 list is sometimes stale). Also follow any def page a parameter table cross-links to (e.g. `graphitem/object`, `dcheck/object`, `usermacro/object`).
   - `<object>/<method>` — per-method parameters.
   RESOLVE each enum / nested object / property from the page that defines it (e.g. `eventsource` on `event/object`).
3. CREATE each `schemas/<version>/<object>/M.json` USING the tables (see File shape + Type map):
   - SET `description` — one line from the method's page.
   - `get` — `properties` = the Common get params block (below) + the method's own params. OVERWRITE a common key only where the page defines its own form of it (e.g. a `sortfield` enum).
   - `create` — `properties` = property table minus read-only / auto-set fields; SET `required` per the page.
   - `update` — same `properties`; SET `required` = the ID field (plus any the page names).
   - `delete` — top level is the array-of-IDs form (below); SET `description`.
   - `mass*` / other specialized methods — model exactly what that page documents.
   MAP types via the table below; keep nested object/array structure the docs define.
4. RUN `./lint.sh schemas/<version>/<object>`.
5. REPEAT 3-4 UNTIL lint prints `PASS`.
6. REPORT.

MANIFEST: do NOT edit `schemas/zabbix-<version>.json` — concurrent scrapes race on that one shared file. The orchestrator reconciles each method's `title`/`description` into it from your finished schema files (title = `M`, description = the schema's `description`), bringing it to parity with `zabbix-7.0.json`.

## Type map

| Zabbix type   | JSON Schema |
|---------------|-------------|
| ID            | `{"type":"string"}` |
| ID/array      | `{"oneOf":[{"type":"string"},{"type":"array","items":{"type":"string"}}]}` |
| boolean       | `{"type":"boolean"}` |
| flag          | `{"type":"boolean"}` |
| integer       | `{"type":"integer"}` |
| float         | `{"type":"number"}` |
| string        | `{"type":"string"}` |
| text          | `{"type":"string"}` |
| timestamp     | `{"type":"integer"}` |
| query         | `{"oneOf":[{"type":"array","items":{"type":"string"}},{"enum":["extend","count"]}]}` |
| object        | `{"type":"object"}` |
| array         | `{"type":"array"}` |
| string/array  | `{"oneOf":[{"type":"string"},{"type":"array","items":{"type":"string"}}]}` |

Enumerated integers get `"enum":[...]`, each value described in `description`.

## File shape

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://zabbix.com/<version>/api/<object>/M",
  "title": "M",
  "description": "<one line: what the method does>",
  "$comment": "Source: https://www.zabbix.com/documentation/<version>/en/manual/api/reference/<object>/<method>",
  "type": "object",
  "properties": { ... },
  "additionalProperties": false
}
```

`delete` top level is `{"type":"array","items":{"type":"string"},"minItems":1}` (keep `$schema`/`$id`/`title`/`description`/`$comment`).

## Common get params

Merge this block verbatim into every `get` schema's `properties`. Overwrite a key only where the method page defines its own form of it.

```json
{
  "countOutput": {"type":"boolean","description":"Return the number of records in the result instead of the actual data."},
  "editable": {"type":"boolean","description":"If set to true, return only objects that the user has write permissions to. Default: false."},
  "excludeSearch": {"type":"boolean","description":"Return results that do not match the criteria given in the search parameter."},
  "filter": {"type":"object","description":"Return only those results that exactly match the given filter. Does not support text-type properties."},
  "limit": {"type":"integer","description":"Limit the number of records returned."},
  "output": {"oneOf":[{"type":"array","items":{"type":"string"}},{"enum":["extend","count"]}],"description":"Object properties to be returned. Default: extend."},
  "preservekeys": {"type":"boolean","description":"Use IDs as keys in the resulting array."},
  "search": {"type":"object","description":"Return results that match the given pattern (case-insensitive). Supports string and text properties."},
  "searchByAny": {"type":"boolean","description":"If true, return results that match any of the criteria given in the filter or search parameter. Default: false."},
  "searchWildcardsEnabled": {"type":"boolean","description":"If true, enables the use of '*' as a wildcard character. Default: false."},
  "sortfield": {"oneOf":[{"type":"string"},{"type":"array","items":{"type":"string"}}],"description":"Sort the result by the given properties."},
  "sortorder": {"oneOf":[{"enum":["ASC","DESC"]},{"type":"array","items":{"enum":["ASC","DESC"]}}],"description":"Order of sorting. ASC or DESC."},
  "startSearch": {"type":"boolean","description":"The search parameter will compare the beginning of fields. Ignored if searchWildcardsEnabled is set."}
}
```

## Report

- object name
- methods created (count + list)
- any method not created + why
