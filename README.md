# Zabbix API — JSON Schemas

JSON Schemas (draft 2020-12) for the `params` of every method in the
[Zabbix API reference](https://www.zabbix.com/documentation/current/en/manual/api/reference).
Two version corpora, transcribed from the raw Markdown docs source
(`git.zabbix.com`, `release/<version>` branch) and cross-checked against the
rendered tables — ground truth, not paraphrased.

| Version | Objects | Methods | Tree           | Index                     |
|:--------|:--------|:--------|:---------------|:--------------------------|
| 7.0     | 58      | 222     | `schemas/7.0/` | `schemas/zabbix-7.0.json` |
| 6.0     | 53      | 193     | `schemas/6.0/` | `schemas/zabbix-6.0.json` |

## Layout

| File                                                | Description                                            |
|:----------------------------------------------------|:-------------------------------------------------------|
| `schemas/<version>/<object>/<object>.<method>.json` | one method's `params` schema                           |
| `schemas/zabbix-<version>.json`                     | index: object → method → path                          |
| `AGENT_SPEC.md`                                     | extraction spec — modeling conventions & type mapping  |
| `PROGRESS-<version>.md`                             | build log                                              |
| `SCHEMAS.md`                                        | schema index (progress + source docs)                  |

## Usage

Each schema describes the JSON-RPC `params` value for one method. Wrap it in the
envelope yourself and validate `params` against the file:

``` json
{ "jsonrpc": "2.0", "method": "host.get", "params": { ... }, "auth": "<token>", "id": 1 }
```

e.g. validate against `schemas/7.0/host/host.get.json`.

**Typing:** schemas follow the docs strictly — `integer` needs a JSON number, an
`ID` needs a JSON string. The live API is loosely typed and accepts quoted
numbers (`"1"`), so real wire payloads may fail strict mode; loosen numeric
fields to `["integer","string"]` in your own copy for wire-tolerant validation.

## Checks

Two independent, non-overlapping layers — Spectral checks the files are valid
draft 2020-12; the `lint*.sh` scripts check repo conventions (dotted `$id` / `title`, `additionalProperties:false`, index in sync, counts). Exit `0` = clean.

``` bash
spectral lint 'schemas/**/*.json'   # JSON Schema validity (.spectral.yaml)
./lint-7.0.sh                       # 7.0 house conventions
./lint-6.0.sh                       # 6.0 house conventions
```
