# Scrape Spec

INPUT: version (e.g. `6.0`), objects (your assigned subset of the work list) NOTATION: `M` = dotted method name (e.g. `token.get`); `<method>` = its tail (e.g. `get`). SOURCE: git raw markdown, one request per page, paced: `https://git.zabbix.com/projects/WEB/repos/documentation/raw/en/manual/api/reference/<path>.md?at=refs/heads/release/<version>` Preflight has already scaffolded every `schemas/<version>/<object>/M.json`. Your job is to FILL it.

STEPS (per assigned object):

1. FETCH `<object>.md` (method list) and `<object>/object.md` (property table).
2. FETCH each `<object>/<method>.md`. Read the table rows from the markdown.
3. EXTRACT per method: parameters (get) or properties (create/update), required fields, enums. Resolve an enum's values from the page that defines them (e.g. `eventsource` on `event/object`).
4. FILL `schemas/<version>/<object>/M.json`: set `description`, add the method's properties (rules below). The scaffold's `$schema`/`$id`/`title`/`$comment`/common block stay as they are.
5. UPDATE `schemas/zabbix-<version>.json`: set each method's `title` and `description`.
6. RUN `./lint.sh schemas/<version>/<object>`; REPEAT 3-6 UNTIL clean.
7. REPORT (format below).

## Type map

| Zabbix type  | JSON Schema                                                                          |
| ------------ | ------------------------------------------------------------------------------------ |
| ID           | `{"type":"string"}`                                                                  |
| ID/array     | `{"oneOf":[{"type":"string"},{"type":"array","items":{"type":"string"}}]}`           |
| boolean      | `{"type":"boolean"}`                                                                 |
| flag         | `{"type":"boolean"}`                                                                 |
| integer      | `{"type":"integer"}`                                                                 |
| float        | `{"type":"number"}`                                                                  |
| string       | `{"type":"string"}`                                                                  |
| text         | `{"type":"string"}`                                                                  |
| timestamp    | `{"type":"integer"}`                                                                 |
| string/array | `{"oneOf":[{"type":"string"},{"type":"array","items":{"type":"string"}}]}`           |
| array        | `{"type":"array"}`                                                                   |
| object       | `{"type":"object"}`                                                                  |
| query        | `{"oneOf":[{"type":"array","items":{"type":"string"}},{"enum":["extend","count"]}]}` |

Enumerated integers get `"enum":[...]`, each value described in `description`. Carry the doc's description text onto each property. Keep nested object/array structure the docs define.

## Method rules

- `get`: the common block is already present. Add the method's own params. Where the page defines a method-specific form of a common key (e.g. a `sortfield` enum), overwrite that key's value.
- `create`: `properties` = object property table, minus read-only / auto-set fields; `required` = the page's required fields.
- `update`: same properties as create; `required` = the object ID field (plus any the page names).
- `delete`: the scaffold is already the array-of-IDs body; set `description`. Where a method's params is an empty array (e.g. `apiinfo.version`, some `logout`), set the body to `{"type":"array","maxItems":0,"minItems":0}`.
- `mass*` and other specialized methods: model what that page documents.
- When an object page defines several structures a create/update accepts (e.g. `history/object`, media type transports, item types), model them as a `oneOf` of the variants.
- `dashboard` widget `fields`: array of `{ "type": <enum from dashboard/object>, "name": string, "value": {} }`, `required` `["type","name","value"]`.

## Filled shape

``` json
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

## Report format

```
<object>: <n> methods
filled: M.json, M.json, ...
unverified: <method> — <reason>   (omit line if none)
```
