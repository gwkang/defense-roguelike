---
name: game-save-implementation
description: Implement or repair versioned game persistence, readback, migration and recovery from an agreed save contract; excludes economy design and session restoration orchestration.
---

## Inputs and owned output
Require the persisted schema, compatibility/recovery policy, storage adapter and commit semantics. Own serialization, reads/writes, migration and focused persistence regression tests. Do not infer reward or cloud conflict policy from storage APIs.

## Execute
Trace the write transaction and the caller's acknowledgement. Report durable success only at the boundary the storage contract guarantees. A failed or pending write must not be presented as a confirmed reward/purchase when that result depends on persistence.

Implement version checks and validate decoded data before exposing it. Preserve original data on failed migration where the storage contract permits. Handle unknown future versions through the stated compatibility policy instead of resetting user progress silently.

Define write ordering and duplicate/retry behavior for the affected path. Use atomic replacement, transactions or the available equivalent as appropriate to the actual storage API; do not claim unsupported durability. Keep cloud merging/account transfer outside scope unless explicitly contracted.

Test successful readback, write failure, malformed data and applicable migration paths using isolated storage. Include overlapping writes or interrupted commits when relevant. Never use real player saves as destructive fixtures.

## Handoff
Report schema/version changes, commit/recovery behavior, tests and compatibility limits. Session restoration belongs to game-session-implementation; rewards and economy rules belong to the rule/design owners. Return unresolved data-loss or merge choices to the contract owner before implementing that branch.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
For implementation and final delivery, apply [the delivery contract](../game-task-planning/references/delivery-contract.md).
