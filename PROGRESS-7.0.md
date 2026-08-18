# Zabbix 7.0 API JSON Schema — Progress

58 API objects, one Sonnet agent per object, launched 10 at a time. Schemas land in `schemas/7.0/<object>/<method>.json`. Conventions: `AGENT_SPEC.md`.

Standing plan: auto-release each wave when the prior clears (no per-wave gate). After Wave 6, run Finalization.

## Finalization (after Wave 6) — COMPLETE

- [x] Full corpus re-validation against Draft 2020-12: 222 files, all conform.
- [x] Normalized singleton `get` schemas to `output`-only (cross-checked raw docs: both pages state "supports only one parameter"). authentication.get + autoregistration.get fixed; housekeeping.get + settings.get were already correct.
- [x] Wrote top-level README.md (usage, layout, conventions, type map, strict-per-docs caveat).
- [x] Generated schemas/zabbix-7.0.json (object -> method -> {path,title,description}); count asserts == file count.
- [x] Final count: 58 objects, 222 methods, none empty.
- [x] Relocated schemas/service/*raw** scratch to /Volumes/T5/TRASH/zabbixapi-spec/tmp/trash; only .json remain under schemas/.

## Wave 1 (running)

- [x] action (4: get, create, update, delete)
- [x] alert (1 method: alert.get)
- [x] apiinfo (1 method: apiinfo.version)
- [x] auditlog (1 method: auditlog.get)
- [x] authentication (2: get, update)
- [x] autoregistration (2: get, update)
- [x] connector (4: get, create, update, delete)
- [x] correlation (4: get, create, update, delete)
- [x] dashboard (4: get, create, update, delete)
- [x] dhost (1 method: dhost.get)

## Wave 2

- [x] dservice (1 method: dservice.get)
- [x] dcheck (1 method: dcheck.get)
- [x] drule (4: get, create, update, delete)
- [x] event (2: get, acknowledge)
- [x] graph (4: get, create, update, delete)
- [x] graphitem (1 method: graphitem.get)
- [x] graphprototype (4: get, create, update, delete)
- [x] hanode (1 method: hanode.get)
- [x] history (3: get, clear, push)
- [x] host (7: get, create, update, delete, massadd, massupdate, massremove)

## Wave 3

- [x] hostgroup (8: get, create, update, delete, massadd, massremove, massupdate, propagate)
- [x] hostinterface (7: get, create, update, delete, massadd, massremove, replacehostinterfaces)
- [x] hostprototype (4: get, create, update, delete)
- [x] housekeeping (2: get, update)
- [x] iconmap (4: get, create, update, delete)
- [x] image (4: get, create, update, delete)
- [x] item (4: get, create, update, delete)
- [x] itemprototype (4: get, create, update, delete)
- [x] discoveryrule (5: get, create, update, delete, copy)
- [x] mfa (4: get, create, update, delete)

## Wave 4

- [ ] maintenance
- [ ] map
- [ ] mediatype
- [x] module (4: get, create, update, delete)
- [ ] problem
- [ ] proxy
- [ ] proxygroup
- [ ] regexp
- [ ] report
- [ ] role

## Wave 5

- [x] sla (5: get, create, update, delete, getsli)
- [x] script (7: get, create, update, delete, execute, getscriptsbyhosts, getscriptsbyevents)
- [x] service (4: get, create, update, delete) [scratch *raw** files to clean in finalization]
- [x] settings (2: get, update — singleton get, no common-get merge)
- [x] task (2: create, get)
- [x] template (7: get, create, update, delete, massadd, massremove, massupdate)
- [x] templatedashboard (4: get, create, update, delete)
- [x] templategroup (8: get, create, update, delete, massadd, massremove, massupdate, propagate)
- [x] token (5: get, create, update, delete, generate)
- [x] trend (1: get — no common-get merge)

## Wave 6

- [x] trigger (4: get, create, update, delete)
- [x] triggerprototype (4: get, create, update, delete)
- [x] user (10: get, create, update, delete, login, logout, checkAuthentication, provision, resettotp, unblock)
- [x] userdirectory (5: get, create, update, delete, test)
- [x] usergroup (4: get, create, update, delete)
- [x] usermacro (7: get, create, update, delete, createglobal, updateglobal, deleteglobal)
- [x] valuemap (4: get, create, update, delete)
- [x] httptest (4: get, create, update, delete)

## DONE — 58 objects, 222 methods, 100% Draft 2020-12 conformant.
