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

Two independent checks. Run both — they do not overlap. Spectral tells you the
files are valid JSON Schema; `lint.sh` tells you they follow the repo conventions.

### 1. JSON Schema validity — Spectral

Validates every file against the official draft 2020-12 meta-schema (plus a
parse / duplicate-key layer). Ruleset: `.spectral.yaml`. From the repo root:

```bash
spectral lint 'schemas/**/*.json'
```

Quote the glob so Spectral's own `**` recursion walks every object directory;
unquoted, zsh (without `globstar`) will not recurse. Exit code is `0` clean,
non-zero on any error — drops straight into CI or a pre-commit hook. Spectral is
a global [mise](https://mise.jdx.dev) tool, so it is already on `PATH` in a
normal shell. If a fresh shell can't find it: `mise reshim`, or call it via
`mise exec -- spectral lint 'schemas/**/*.json'`.

### 2. House conventions — `./lint.sh`

Enforces this repo's own rules (this does **not** validate JSON Schema itself):

```bash
./lint.sh          # full report
./lint.sh --quiet  # summary + failures only
```

- `$schema`, dotted `$id` (`https://zabbix.com/7.0/api/<object>/<object>.<method>`),
  `title` equal to the dotted method name, non-empty `description`, a `$comment`
  citing the doc Source URL.
- `additionalProperties:false` on object schemas; delete-style array-of-id-strings
  shape (`items.type:string` + `minItems`, or `maxItems:0` for empty-param methods).
- filename prefix matches its directory (`<object>`).
- `methods.json` in sync with files on disk (object set, method set, paths, counts).
- only `.json` lives under `schemas/`.
- object/method count regression guard (`EXPECT_OBJECTS` / `EXPECT_METHODS` in
  `lint.sh`; bump those when intentionally adding or removing a schema).

Exit codes: `0` clean, `1` failures, `2` missing dependency (`jq`, `python3`).
Convention rules live in `lint/rules.jq`.

## Source

Built by scraping `https://www.zabbix.com/documentation/7.0/en/manual/api/reference`
and its raw Markdown source at
`git.zabbix.com/projects/WEB/repos/documentation` (branch `release/7.0`).
See `AGENT_SPEC.md` for the exact extraction procedure.
