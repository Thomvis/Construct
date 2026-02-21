# Creature Action Parser Upgrade

## Goal
Improve `CreatureActionParser` coverage for real monster weapon-action text while evolving the parsed model in a backward-compatible (forward-migrating) way.

## Plan
- Add additive model fields for advanced semantics.
- Extend parser grammar for known high-frequency patterns.
- Add safe fallback parsing for unstructured tails.
- Run focused tests and snapshot checks to measure improvement.

## Progress
- [x] Audited current failures from `testAllMonsterActions` snapshot.
- [x] Implemented additive model updates.
- [x] Implemented parser updates.
- [x] Added test coverage for new model fields, including `failureMargin`.
- [x] Ran tests.
- [x] Measured before/after parse coverage.

## Result
- Before initial upgrade: 91 problematic entries in `testAllMonsterActions` snapshot output (`3` complete parse failures).
- After upgrade + stricter attack filter: 57 problematic entries, all partial parses (0 complete parse failures).

## Notes
- Model versions were bumped to force recomputation from source `input`.
- Snapshot was regenerated after parser/filter changes.
