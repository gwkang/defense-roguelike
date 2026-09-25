---
name: game-rule-implementation
description: Implement or repair an already specified game rule or deterministic domain transition, without taking over input devices, UI or session lifecycle.
---

## Inputs
An adequate rule/state contract, related architecture, scope and project verification commands. If rule meaning is unresolved, return to the design owner; do not invent gameplay.

## Execute
Inspect current source and unrelated edits. Own command validation, rule state transitions, results and semantic events. Keep device input, movement, scene/session lifecycle and presentation adapters outside this change unless separately scoped to an available owner.
Implement the smallest complete rule change. Add or adapt meaningful regression tests for the changed rule using isolated fixtures. Preserve RNG/version behavior when the contract requires reproducibility; do not impose determinism on every game.
Test normal, boundary, rejected command and relevant interruption cases. Run the project's required checks. Document the exact changed artifacts, commands, outcomes and remaining limitations.
Expose event timing and cancellation through the existing contract. Do not make animation or sound callbacks independently award rewards or damage. Return interface changes to technical design rather than extending scope silently.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
For implementation and final delivery, apply [the delivery contract](../game-task-planning/references/delivery-contract.md).
