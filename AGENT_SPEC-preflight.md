# Preflight Spec

INPUT: version (e.g. `6.0`) SOURCE: crw the reference index; git raw markdown for commentary; one request per page. OUTPUT: this version's manifest + a scaffolded skeleton for every method. Built only from this version's own docs.

STEPS:

1. RUN — the index is the work list:

   ```
   crw "https://www.zabbix.com/documentation/<version>/en/manual/api/reference/" -f links \
     | grep -E '/<version>/en/manual/api/reference/' | sed -E 's#.*/api/reference/?##; s#/$##' | grep -vE '^$' | sort -u
   ```

2. EXTRACT: objects = single-segment lines; methods = `<object>/<method>` lines where `<method>` is not `object`. `dashboard/widget_fields` and its sub-pages are field-spec pages, not methods — they stay out of the catalog.

3. RUN:

   ```
   curl -s "https://git.zabbix.com/projects/WEB/repos/documentation/raw/en/manual/api/reference_commentary.md?at=refs/heads/release/<version>"
   ```

4. EXTRACT: the `Data types` table and the `Common "get" method parameters` table.

5. VERIFY: every data type appears in `AGENT_SPEC.md`'s type map. MISMATCH -> STOP, REPORT the drift.

6. BUILD `$defs.commonGetParams`: map each common-get param from step 4 to its schema via the type map. This version's own table is the only source.

7. CREATE `schemas/zabbix-<version>.json`:

   - `$comment`, `schema_dialect`, `source`, `object_count`, `method_count`.
   - `objects`: `<object>` -> `<object>.<method>` -> `{ "path": "schemas/<version>/<object>/<object>.<method>.json" }` (title/description filled during scrape).
   - `$defs.commonGetParams` from step 6.

8. SCAFFOLD every method's skeleton (deterministic): `./bin/scaffold.sh <version>`. Each file gets `$schema`, `$id`, `title`, empty `description`, `$comment` Source URL, and a body by method tail — `get`: `type:object` with `commonGetParams` as `properties` and `additionalProperties:false`; `delete`: `type:array, items:{type:string}, minItems:1`; else: `type:object, properties:{}, additionalProperties:false`. Scrape fills the rest.

9. OUTPUT: GO (index + commentary read, manifest + scaffolds written) or NO-GO + the drift.
