# ADR-002 — Save Integrity and In-Fight Resume

## Decision

Use a local JSON envelope with schema version, exact serialized payload text, SHA-256 checksum, and a previous known-good backup. Persist the current fight after every exchange using a deterministic fight seed plus exported combat state.

## Why

A premium offline game must not lose a career on relaunch. The v0.1 prototype also allowed a player to force-close a losing bout and restart it from exchange zero. That undermines both roguelike stakes and QA reproducibility.

## v2 changes

- New `career_v2.json` primary and backup files
- Backup is replaced only if the previous primary validates successfully
- Legacy v1 envelope can be migrated into the v2 state shape
- `fight_seed` and `active_fight` are part of career state
- Combat engine exports/restores round, exchange, HP, stamina, scoring, cards, result, and log
- Active fight state is autosaved after every player action

## Known limitation

The migration path and serialization logic are structurally implemented but still require Godot runtime tests with intentionally corrupted and legacy fixture files.
