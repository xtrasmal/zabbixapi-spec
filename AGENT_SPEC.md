# Zabbix 7.0 API — JSON Schema Extraction Spec

You are ONE agent responsible for ONE Zabbix API object group. Produce a JSON Schema
(draft 2020-12) for the `params` of every method in your assigned object, by scraping the
official Zabbix 7.0 documentation.

## Source

Base URL: `https://www.zabbix.com/documentation/7.0/en/manual/api/reference/<object>`

- Object index page (lists methods + the object's property table):
  `.../reference/<object>`
- Each method page:
  `.../reference/<object>/<method>`  (e.g. `.../reference/host/get`)

## Procedure

1. Fetch your object's index page. Extract:
   - the full list of methods (e.g. `host.get`, `host.create`, `host.massadd`, ...)
   - the object **property table** (the "<Object> object" section: property name, type, description).
     This is the source of truth for create/update field schemas.
2. For EACH method, fetch its method page. When calling WebFetch, demand the COMPLETE
   parameter table VERBATIM — every row, every column — and explicitly instruct it
   "do not summarize or omit rows; return the full markdown table". Also capture the
   "Return values" description.
3. Build one JSON Schema per method (see layout + rules below).
4. Write each schema to disk.
5. Return a concise report (see Reporting).

**Pacing (mandatory):** fetch pages one at a time, not back-to-back in parallel. This is a
polite-scraping requirement. Process your methods sequentially.

**Do NOT run `rm` (it is disabled by policy).** Do not clean up scratch/temp files at all —
they are session-isolated and harmless. Leave any curl/HTML dumps where they are.

## Fidelity requirement (mandatory)

WebFetch runs pages through a small summarizing model and HAS BEEN OBSERVED TO FABRICATE
table rows (invented parameter/property names and enum values). Do NOT trust WebFetch's
paraphrase as ground truth for parameter or property tables.

**Preferred ground-truth source (best):** the docs are generated from raw Markdown in the
Zabbix git repo. Fetch that directly — it is the literal source, no rendering, no summarizer:
`curl -s "https://git.zabbix.com/projects/WEB/repos/documentation/raw/en/manual/api/reference/<object>/<method>.md?at=refs/heads/release/7.0"`
(and `.../reference/<object>/object.md` for the property table, `.../reference/<object>.md` for
the method list). Cross-check a couple of key cells against the rendered HTML page to confirm
the branch/content matches. If the raw-markdown path 404s, fall back to raw HTML below.

For every parameter/property table you schema:
1. Fetch the RAW HTML with `curl -s <url>` (pace requests; one at a time) — OR the raw Markdown
   source above (preferred).
2. Read the actual `<table>` rows — parse them (Python stdlib `html.parser`/`re` is fine) or
   read the raw HTML directly. The real names/types/enums come from the HTML, not the summary.
3. When the docs reference an enum by name but give the numbers on another object's page
   (e.g. action references `eventsource` values defined on `event/object`), fetch that page
   too and resolve the actual numeric values. Never invent an enum.
4. Validate every finished schema against the Draft 2020-12 meta-schema (Python `jsonschema`
   `Draft202012Validator.check_schema`) before reporting.

If you cannot verify a table against raw HTML, say so explicitly in your report rather than
emitting a guessed schema.

## Output layout

Write files to (paths are absolute):

```
/Users/xander/code/www/idiot/zabbixapi-spec/schemas/7.0/<object>/<method>.json
```

Where `<method>` is the dotted method name, e.g.
`schemas/7.0/host/host.get.json`, `schemas/7.0/host/host.massadd.json`.

## Schema rules

Each file is a JSON Schema (draft 2020-12) describing the JSON-RPC `params` for that method.

Skeleton:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://zabbix.com/7.0/api/<object>/<method>",
  "title": "<method>",
  "description": "<one line: what the method does>",
  "$comment": "Source: https://www.zabbix.com/documentation/7.0/en/manual/api/reference/<object>/<method>",
  "type": "object",
  "properties": { ... },
  "additionalProperties": false
}
```

Notes:
- `delete` methods take an array of IDs as `params` (not an object). Represent as:
  `{"type":"array","items":{"type":"string"},"minItems":1}` and put that at top level
  (replace the `object` skeleton). Keep `$schema/$id/title/description/$comment`.
- `get` methods: include the object-specific filter/selection params from the method page
  AND merge in the **common get parameters** listed below.
- `create`: properties = the object property table (omit read-only / auto-generated fields
  like the object's own ID when the docs mark it read-only). Mark required fields via
  `"required": [...]` per the method page notes.
- `update`: same properties as create, but the object ID field IS required. Set `required`
  to just the ID field unless the docs say otherwise.
- `massadd` / `massupdate` / `massremove` / other specialized methods: model exactly what
  that method page documents.

### Zabbix type → JSON Schema mapping

| Zabbix type   | JSON Schema |
|---------------|-------------|
| ID            | `{"type":"string"}` (Zabbix IDs are numeric strings) |
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

- When the docs enumerate allowed integer values (e.g. `0 - (default) ...; 1 - ...`), add an
  `"enum": [0,1,...]` and describe each value in the `description`.
- Put the doc's description text into each property's `"description"`.
- Preserve nested object/array structure when the docs define sub-properties.

### Common "get" method parameters (merge into every `get` schema)

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

## Reporting

Return ONLY this (no prose padding):
- object name
- methods found (count + list)
- files written (count + relative paths)
- any methods you could NOT schema and why
