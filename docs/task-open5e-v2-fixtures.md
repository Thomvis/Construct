# Open5e v2 Fixture and Mapping Update

## Goal
Align default Open5e fixture data with v2 while preserving stat block quality in parsed models.

## Plan
- Reconstruct missing stat block details from v2 structured fields.
- Preserve action ordering and usage annotations.
- Replace oversized default fixtures with compact, reproducible v2 exports.
- Validate with focused snapshot/parser tests.

## Progress
- [x] Added v2 senses reconstruction (`darkvision`, `blindsight`, `tremorsense`, `truesight`, `passive Perception`).
- [x] Added v2 action ordering via `order_in_statblock`.
- [x] Added v2 action suffix reconstruction from `usage_limits` and `legendary_action_cost`.
- [x] Added form-condition suffix reconstruction from `limited_to_form` (e.g. `Vampire Form Only`).
- [x] Normalized v2 creature `type` to lowercase to preserve monster-type parser compatibility.
- [x] Added synthesized legendary intro text when legendary actions exist.
- [x] Added `scripts/update-open5e-fixtures.sh` to fetch/filter fixtures from Open5e v2.
- [x] Extended fixture updater to also fetch v1 monsters and merge missing usage metadata (notably recharge) into v2 action objects.
- [x] Normalized v2 spell casting-time tokens (e.g. `action`, `1minute`, `reaction`) into human-readable text in decoder output.
- [x] Regenerated `Sources/Compendium/Fixtures/monsters.json` and `Sources/Compendium/Fixtures/spells.json` with compact payloads.
- [x] Regenerated snapshots for:
  - `Open5eMonsterDataSourceReaderTest/test`
  - `CreatureActionParserTest/testAllMonsterActions`
  - `Open5eMonsterDataSourceReaderTest/testDefaultContentSnapshot`
- [x] Verified focused tests:
  - `Open5eMonsterDataSourceReaderTest/test`
  - `Open5eMonsterDataSourceReaderTest/testMultipleMovements`
  - `CreatureActionParserTest/testAllMonsterActions`
- [x] `Open5eMonsterDataSourceReaderTest/testDefaultContentSnapshot`

## Notes
- Open5e v2 creature serializer does not emit `senses` or `legendary_desc` as v1 strings; they are represented as structured fields.
- Open5e v2 `srd-2014` currently omits most recharge values from `usage_limits`; fixture generation now backfills these from v1 monster action names during update.
- Fixture updater intentionally strips repeated document/publisher metadata to keep fixture size smaller while preserving decode-relevant fields.
