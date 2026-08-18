# Zabbix 6.0 API JSON Schema — Progress

53 API objects, one Sonnet agent per object, launched ~10 at a time (crw edition: every page load — raw git markdown on `release/6.0` plus the rendered site cross-check — goes through the `crw` CLI).

Schemas land in `schemas/6.0/<object>/<object>.<method>.json` (versioned 3-level layout). Conventions match the 7.0 corpus; the 6.0 house-rules checker is `lint-6.0.sh` + `lint/rules-6.0.jq`, scoped to `schemas/6.0/`. JSON Schema validity is owned separately by Spectral (`spectral lint 'schemas/6.0/**/*.json'`).

## Finalization — COMPLETE

- [x] Full corpus re-validation against Draft 2020-12: 193 files, all conform (python `jsonschema.Draft202012Validator.check_schema` and Spectral, zero errors).
- [x] Normalized `master_itemid` from `integer` to `string` (Zabbix IDs are numeric strings) in item.create, item.update, discoveryrule.create, discoveryrule.update.
- [x] Normalized `user.checkAuthentication` to the official camelCase method name (filename, `$id`, and `title`).
- [x] Verified `auditlog.get` correctly omits `editable` against the 6.0 `auditlog/get` param table — the 6.0 doc does not list it (a legitimate version difference from 7.0, not a defect).
- [x] Confirmed `$defs`/`$ref` reuse in the 20 files that use it matches the 7.0 house style (55 files there) — no churn needed.
- [x] Generated `schemas/zabbix-6.0.json` (object -> method -> {path,title,description}); `object_count`/`method_count` assert == files on disk.
- [x] Added `lint-6.0.sh` + `lint/rules-6.0.jq` (6.0 conventions checker, sibling of `lint-7.0.sh`); `EXPECT_OBJECTS=53`, `EXPECT_METHODS=193`. Runs clean, exit 0.
- [x] Final count: 53 objects, 193 methods, none empty.

## Version note (6.0 vs 7.0 object set)

- Absent in 6.0 (7.0-only): connector, mfa, module, proxygroup, templategroup, userdirectory.
- Present in 6.0 only (relative to the 7.0 corpus): configuration.
- Net: 58 − 6 + 1 = 53 objects.

## Inventory (53 objects, 193 methods)

- [x] action (4): create, delete, get, update
- [x] alert (1): get
- [x] apiinfo (1): version
- [x] auditlog (1): get
- [x] authentication (2): get, update
- [x] autoregistration (2): get, update
- [x] configuration (3): export, import, importcompare
- [x] correlation (4): create, delete, get, update
- [x] dashboard (4): create, delete, get, update
- [x] dcheck (1): get
- [x] dhost (1): get
- [x] discoveryrule (5): copy, create, delete, get, update
- [x] drule (4): create, delete, get, update
- [x] dservice (1): get
- [x] event (2): acknowledge, get
- [x] graph (4): create, delete, get, update
- [x] graphitem (1): get
- [x] graphprototype (4): create, delete, get, update
- [x] hanode (1): get
- [x] history (2): clear, get
- [x] host (7): create, delete, get, massadd, massremove, massupdate, update
- [x] hostgroup (7): create, delete, get, massadd, massremove, massupdate, update
- [x] hostinterface (7): create, delete, get, massadd, massremove, replacehostinterfaces, update
- [x] hostprototype (4): create, delete, get, update
- [x] housekeeping (2): get, update
- [x] httptest (4): create, delete, get, update
- [x] iconmap (4): create, delete, get, update
- [x] image (4): create, delete, get, update
- [x] item (4): create, delete, get, update
- [x] itemprototype (4): create, delete, get, update
- [x] maintenance (4): create, delete, get, update
- [x] map (4): create, delete, get, update
- [x] mediatype (4): create, delete, get, update
- [x] problem (1): get
- [x] proxy (4): create, delete, get, update
- [x] regexp (4): create, delete, get, update
- [x] report (4): create, delete, get, update
- [x] role (4): create, delete, get, update
- [x] script (6): create, delete, execute, get, getscriptsbyhosts, update
- [x] service (4): create, delete, get, update
- [x] settings (2): get, update
- [x] sla (5): create, delete, get, getsli, update
- [x] task (2): create, get
- [x] template (7): create, delete, get, massadd, massremove, massupdate, update
- [x] templatedashboard (4): create, delete, get, update
- [x] token (5): create, delete, generate, get, update
- [x] trend (1): get
- [x] trigger (6): adddependencies, create, delete, deletedependencies, get, update
- [x] triggerprototype (4): create, delete, get, update
- [x] user (8): checkAuthentication, create, delete, get, login, logout, unblock, update
- [x] usergroup (4): create, delete, get, update
- [x] usermacro (7): create, createglobal, delete, deleteglobal, get, update, updateglobal
- [x] valuemap (4): create, delete, get, update

## DONE — 53 objects, 193 methods, 100% Draft 2020-12 conformant.
