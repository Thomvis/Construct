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
- [x] Regenerated `Sources/Compendium/Fixtures/monsters-2014.json` and `Sources/Compendium/Fixtures/spells-2014.json` with compact payloads.
- [x] Added `Sources/Compendium/Fixtures/monsters-2024.json` and `Sources/Compendium/Fixtures/spells-2024.json` from Open5e v2 (`document__key=srd-2024`) without v1 augmentation.
- [x] Renamed fixture update script outputs to `*-2014.json` defaults and added explicit output overrides (`OPEN5E_MONSTERS_OUTPUT`, `OPEN5E_SPELLS_OUTPUT`) plus v1 augmentation control (`OPEN5E_V1_AUGMENT`).
- [x] Added a new default realm/document pair for 2024 rules:
  - Realm `core2024` (`Core 5e (2024)`)
  - Document `srd52` (`SRD 5.2`)
- [x] Updated 2014 realm display name to `Core 5e (2014)` while keeping stable id `core`.
- [x] Updated default content import/versioning to track/import 4 fixture components (2014 + 2024, monsters + spells), with backward-compatible decoding of legacy version payloads.
- [x] Updated `CompendiumImporter` to use `task.document.realmId` for reader realm routing (instead of hard-coded `core`).
- [x] Added v2 casting-time normalization for 2024 tokens (`bonus_action`, `minute`, `hour`).
- [x] Added focused regression tests for:
  - importer realm routing via `CompendiumImporterTest/testUsesTaskDocumentRealmForReader`
  - 2024 casting-time token normalization via `Open5eMonsterDataSourceReaderTest/testV2SpellCastingTimeNormalizationFor2024Tokens`
  - 2024 fixture readability via `Open5eMonsterDataSourceReaderTest/testDefault2024ContentCanBeRead`
  - legacy `DefaultContentVersions` decoding via `KeyValueStoreEntityTest/testDefaultContentVersionsDecodesLegacyPayload`
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
- Open5e v2 `srd-2024` is available under document key `srd-2024` and includes updated spell casting-time tokens (`bonus_action`, `minute`, `hour`).
- Fixture updater intentionally strips repeated document/publisher metadata to keep fixture size smaller while preserving decode-relevant fields.
