# Zabbix 7.0 API — JSON Schemas

JSON Schemas (draft 2020-12) for the `params` of every method in the
[Zabbix 7.0 API reference](https://www.zabbix.com/documentation/7.0/en/manual/api/reference).

- **58 API objects**, **222 methods**, one schema file per method.
- Every file validates against the draft 2020-12 meta-schema
  (`jsonschema.Draft202012Validator.check_schema`).
- Each schema was built from the **raw Markdown source** of the docs
  (`git.zabbix.com`, `release/7.0` branch), cross-checked against the rendered
  HTML tables. Parameter and property tables are transcribed from ground truth,
  not paraphrased.

## Layout

```
schemas/<object>/<object>.<method>.json     e.g. schemas/host/host.get.json
methods.json                                 index: object -> method -> {path,title,description}
AGENT_SPEC.md                                the extraction spec each object was built against
PROGRESS.md                                  build log (6 waves + finalization)
```

Each schema describes the JSON-RPC `params` value for one method. Wrap it in the
usual envelope yourself:

```json
{ "jsonrpc": "2.0", "method": "host.get", "params": { ... }, "auth": "<token>", "id": 1 }
```

Validate the `params` object against `schemas/host/host.get.json`.

## Conventions

- **`get` methods** — object-specific filter/selection params plus the common
  get-method parameters (`output`, `filter`, `search`, `limit`, `sortfield`,
  `preservekeys`, `countOutput`, ...). Singleton objects whose docs state the
  method "supports only one parameter" (`authentication`, `autoregistration`,
  `housekeeping`, `settings`) carry **only `output`** — the common-get set is
  omitted because those pages do not document it.
- **`create`** — properties are the object's property table. Read-only and
  auto-generated fields (the object's own ID, computed timestamps) are omitted.
  `required` follows the method page.
- **`update`** — same properties as `create`, with the object ID field required.
- **`delete`** — `params` is a top-level array of ID strings
  (`{"type":"array","items":{"type":"string"},"minItems":1}`), not an object.
- **`mass*` / specialized methods** (`massadd`, `propagate`, `execute`,
  `getsli`, `replacehostinterfaces`, `push`, `generate`, `test`, ...) — modeled
  exactly as their own method page documents.
- **Nested structures** (dashboard pages/widgets/fields, httptest steps, sla
  schedule/downtime, trigger dependencies/tags, ...) are modeled with `$defs`
  inside the file that uses them.
- Every property carries its doc `description`; enumerated integer values carry
  an `enum` with each value explained in the description.
- `additionalProperties: false` on object schemas — unknown params are rejected.

### Zabbix type mapping

| Zabbix type | JSON Schema |
|-------------|-------------|
| ID          | `{"type":"string"}` (Zabbix IDs are numeric strings) |
| ID/array    | `oneOf` string or array of strings |
| boolean / flag | `{"type":"boolean"}` |
| integer / timestamp | `{"type":"integer"}` |
| float       | `{"type":"number"}` |
| string / text | `{"type":"string"}` |
| query       | `oneOf` array of strings or `extend`/`count` |
| object / array | `{"type":"object"}` / `{"type":"array"}` |

## Known caveat: strict-per-docs typing vs. a loosely-typed API

The Zabbix docs type many numeric fields as `integer` (and IDs as string-typed
`ID`). These schemas follow the docs **strictly**: `integer` fields require a
JSON number, `ID` fields require a JSON string.

The live Zabbix API is loosely typed — its PHP backend coerces quoted-string
numbers (`"1"`) and bare integers interchangeably on input, and its own response
examples often quote numeric values. If you validate **real request payloads**
that were built for the wire and use quoted numbers where the docs say
`integer`, expect strict-mode failures. This is a deliberate fidelity choice:
the schemas mirror the documented types. If you need wire-tolerant validation,
loosen numeric fields to accept `["integer","string"]` in your own copy rather
than treating the strict schemas as wrong.

## Linting

`./lint.sh` is the official linter for this corpus. Run it from the repo root:

```bash
./lint.sh          # full report
./lint.sh --quiet  # summary + failures only
```

It checks every `schemas/<object>/<object>.<method>.json` for:

1. **Meta-schema conformance** — valid draft 2020-12 (reference `jsonschema` engine).
2. **Conventions** — `$schema`, dotted `$id`
   (`https://zabbix.com/7.0/api/<object>/<object>.<method>`), `title` equal to the
   dotted method name, non-empty `description`, a `$comment` citing the doc Source
   URL, `additionalProperties:false` on object schemas, and the delete-style
   array-of-id-strings shape (`items.type:string` + `minItems`, or `maxItems:0`
   for empty-param methods).
3. **Naming** — filename prefix matches its directory (`<object>`).
4. **Index sync** — `methods.json` matches the files on disk (object set, method
   set, paths, and counts).
5. **No stray files** — only `.json` lives under `schemas/`.
6. **Regression guard** — object/method totals match `EXPECT_OBJECTS` /
   `EXPECT_METHODS` in `lint.sh`; bump those when intentionally adding or removing
   a schema.

Exit codes: `0` clean, `1` lint failures, `2` missing dependency (`jq`, `python3`,
or the `jsonschema` module). Convention rules live in `lint/rules.jq`.

## Source

Built by scraping `https://www.zabbix.com/documentation/7.0/en/manual/api/reference`
and its raw Markdown source at
`git.zabbix.com/projects/WEB/repos/documentation` (branch `release/7.0`).
See `AGENT_SPEC.md` for the exact extraction procedure.
