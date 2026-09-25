---
name: game-content-loading
description: Implement or repair asynchronous game resource acquisition, caching, shared references and release; excludes scene transition decisions and asset authoring.
---

## Inputs and owned output
Require resource identity/version, format/import expectations, consumers and lifetime/cancellation contracts. Own the runtime resource loader/cache, handles and acquisition/release regression tests.

## Execute
Inspect cache keys, in-flight requests and handle ownership. Separate request cancellation from the lifetime of a shared underlying acquisition; cancelling one consumer must not invalidate another consumer's handle.

Make success, failure and cancellation observable. Propagate the consumer lifetime token or agreed equivalent. If a consumer disappears before completion, release its result without activating a scene. The session owner decides whether a loaded result is still eligible for adoption.

Apply specified retry, fallback, memory and version policies. Do not turn a missing or incompatible asset into silent success. Account for engine-thread restrictions on creation/disposal through the configured runtime adapter.

Pair acquisition with release across success, partial failure, cancellation and repeated teardown. Test concurrent consumers, duplicate requests, late results and final-reference disposal. Measure resource growth when the reported bug concerns repeated loading; a completed promise alone does not prove cleanup.

## Handoff
Report resource/handle contract, changed loader files and failure/lifetime evidence. Route invalid exports to the asset/import owner and transition eligibility to game-session-implementation. Do not author assets, serialize saves or decide scene order in the loader.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
For implementation and final delivery, apply [the delivery contract](../game-task-planning/references/delivery-contract.md).
