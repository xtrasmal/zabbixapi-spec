# Preflight Spec (phase 1)

INPUT: `<version>` (e.g. `6.0`). SOURCE: crw the reference index; git raw markdown for commentary; one request per page, paced. OUTPUT: this version's PURE-INDEX manifest `schemas/zabbix-<version>.json` (same shape as `zabbix-7.0.json`). Built only from this version's own docs. No scaffold, no `$defs`.

STEPS:

1. RUN — the index is the work list:

   ```
   crw "https://www.zabbix.com/documentation/<version>/en/manual/api/reference/" -f links \
     | grep -E '/<version>/en/manual/api/reference/' | sed -E 's#.*/api/reference/?##; s#/$##' | grep -vE '^$' | sort -u
   ```

2. EXTRACT: objects = single-segment lines; methods = `<object>/<method>` lines where `<method>` is not `object`. `dashboard/widget_fields` and its sub-pages are field-spec pages, not methods — keep them out.

3. RUN:

   ```
   curl -s "https://git.zabbix.com/projects/WEB/repos/documentation/raw/en/manual/api/reference_commentary.md?at=refs/heads/release/<version>"
   ```

4. EXTRACT: the `Data types` table and the `Common "get" method parameters` table.

5. VERIFY against `AGENT_SPEC.md`: every data type appears in its Type map; every common-get param appears in its Common get params block. MISMATCH -> STOP, REPORT the drift (this version's own tables are the only source).

6. CREATE `schemas/zabbix-<version>.json` — PURE INDEX, identical shape to `zabbix-7.0.json`:

   - `$comment`, `schema_dialect`, `source`, `object_count`, `method_count`.
   - `objects`: `<object>` -> `<object>.<method>` -> `{ "path": "schemas/<version>/<object>/<object>.<method>.json", "title", "description" }` (title/description from the index/method pages).
   - No `$defs`. No per-method files (scrape phase creates those).

7. OUTPUT: GO (index + commentary verified, manifest written) or NO-GO + the drift.
