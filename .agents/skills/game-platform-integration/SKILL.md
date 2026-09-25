---
name: game-platform-integration
description: Implement or repair game platform SDK and external service adapters, including failure and callback handling; excludes external deployment and product policy decisions.
---

## Inputs and owned output
Require the requested capability, target SDK/API version, interface contract and allowed test environment. Own the platform adapter, result translation and contract tests. Use current official documentation for the specific installed API when needed.

## Execute
Keep platform imports and credentials outside game-domain modules. Translate provider responses into explicit success, failure, cancellation and unavailable results; preserve diagnostic detail without logging secrets or unnecessary player data.

Trace duplicate callbacks, late completion, timeout and retry. Check whether an operation is idempotent before retrying a side effect. A provider acknowledgement, entitlement decision and durable local commit may be different stages; keep the contract's reward/purchase authority explicit.

Dispose listeners with their owning lifetime. Respect the specified offline/unavailable fallback without inventing monetization, consent or entitlement rules. Use a sandbox/mock path for development when authorized; do not make real purchases, publish builds or mutate live service configuration as adapter verification.

Test applicable availability, success, rejection, interruption and duplicate-delivery paths. Label mock evidence separately from actual SDK/device evidence. Escalate missing target access as an unverified boundary, not a successful integration.

## Handoff
Deliver adapter/interface changes, supported API version and evidence by environment. Return durable local commit issues to game-save-implementation, late session adoption to game-session-implementation and ambiguous product policy to its owner.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
For implementation and final delivery, apply [the delivery contract](../game-task-planning/references/delivery-contract.md).
