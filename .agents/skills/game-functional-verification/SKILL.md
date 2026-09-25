---
name: game-functional-verification
description: Verify a changed game against its functional and regression criteria using current artifacts; do not repair product or evidence.
---

## Inputs/output
Use acceptance criteria, reproducible fixture, exact candidate and applicable environment. Output criterion, procedure, expected/actual, evidence ID, candidate identity and pass/fail/unverified status.
Execute the original defect reproduction or requested feature flow and affected boundaries. Reuse unrelated valid evidence only when its input dependencies remain unchanged. Required stale evidence is not a pass.
Do not create product fixes or a new test harness during verification; return missing shared fixtures/harness to game-test-infrastructure and unclear scenarios to game-test-design. Local regression fixtures belong to the relevant implementer. Static tests do not prove UI rendering or audio quality. For a playable functional interface before final polish, exercise the agreed player actions, state feedback and outcome in the actual target runtime; core-only tests or a visual preview are insufficient. Reserve final visual fidelity for the UI runtime-validation and acceptance roles. Route audio-quality claims through available specialist validation and acceptance.
Check candidate identity before and after observation. Separate environment blocks from observed product failures. Report failed requirements to their owner and do not average failures into overall success.

For multi-owner changes, execute the assigned cross-module scenarios against the assembled candidate. Missing test assertions return to the plan's test-code writer, not automatically to shared infrastructure. Report evidence to the coordinator for the review and final gates in [the delivery contract](../game-task-planning/references/delivery-contract.md); functional success alone is not final acceptance.

Before judging, apply [current-state and prior-record review](../game-task-planning/references/verification-scope.md#review-the-current-state-before-alleging-a-defect): inspect relevant implementation and available wiki/decision/review records, check counterevidence, and report no findings when warranted. Do not expand scope or manufacture defects.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
