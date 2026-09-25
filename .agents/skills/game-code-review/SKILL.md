---
name: game-code-review
description: Review game-code changes against an agreed contract and current evidence without editing the implementation.
---

## Input/output
Use request, changed source, relevant callers and verification results. Output actionable findings with location, trigger, consequence, severity and repair owner; otherwise state the reviewed scope and limits.
Prioritize state ownership, duplicate rewards/events, lifetime/cancellation, save compatibility, boundary handling and real regression risks. Do not request speculative refactoring unrelated to the change.
Read callers and tests before asserting a defect. Distinguish inspected facts, execution evidence and inference. If authored by the same reviewer, label it self-review; do not claim independent approval.
Do not patch code, edit tests to pass, or declare rendered/art quality from code. Return concrete findings to implementation and require evidence against the final candidate.

Apply the [shared coding decisions](../game-task-planning/references/delivery-contract.md#implementation-completion) to changed code: identify concrete invariant bypasses, responsibility/dependency coupling or avoidable cost. Report their trigger and impact; missing pattern names or unrelated cleanup are not findings.

When the change has a technical-design revision, check the changed callers and consumers against its responsibility, state-owner, interface, lifecycle and provisional-structure boundaries. Treat an undocumented expansion of provisional code, or its promotion into a shared baseline without recorded criteria, as a finding only when you can name the concrete ownership, invariant, lifecycle or change-risk consequence. Return missing or conflicting architecture to `game-technical-design`; do not prescribe a speculative refactor from review.

Check the assembled change and cross-module tests when multiple owners contributed. Apply the project's review policy using [the delivery contract's review and final-candidate sections](../game-task-planning/references/delivery-contract.md). Review changed callers, existing conventions and maintainability consequences relevant to the request; do not impose a new pattern merely for stylistic consistency. Runtime parallel changes also need scrutiny of the declared data ownership, execution thread and cancellation/shutdown behavior.

Before judging, apply [current-state and prior-record review](../game-task-planning/references/verification-scope.md#review-the-current-state-before-alleging-a-defect): inspect relevant implementation and available wiki/decision/review records, check counterevidence, and report no findings when warranted. Do not expand scope or manufacture defects.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
