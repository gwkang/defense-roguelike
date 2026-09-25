---
name: indie-game-bugfix
description: Coordinate reproduction, diagnosis, owner-specific repair and regression verification for an indie-game defect.
---

## Inputs and output
Require the routing record, expectation source and confirmed decision state (or authorized delegated selection). Missing/conflicting expectations return to game-feature-spec without blocking observation collection. Start with expected/actual behavior, environment and any existing reproduction. Own defect flow policy and resolution conditions. Use the already active [game-workflow-supervision](../game-workflow-supervision/SKILL.md), or activate it when the routed request requires supervision; never create a second supervisor or route back to game-workflow.

## Execute
Reuse current reproduction or apply game-bug-reproduction; then apply game-bug-diagnosis. An unconfirmed hypothesis is not an established cause. Route repair to the cause owner using game-task-planning: rule, input, movement, camera, session, loading, save or platform implementation as appropriate; existing UI implementation owns UI defects. Missing specialties remain explicit prerequisites.
If diagnosis needs shared instrumentation, game-test-infrastructure implements the scoped tooling and diagnosis resumes with its evidence. Use game-technical-design when the repair leaves consequential structural, algorithmic, data or lifecycle decisions unresolved; reuse adequate existing contracts and keep straightforward repairs local. game-test-design can define missing regression scenarios. Neither diagnosis nor verification quietly becomes a product/harness writer.
Do not send a sound duplication symptom to sound-file production without diagnosing event ownership. Keep opportunistic refactoring out of the repair.
Follow [the delivery contract](../game-task-planning/references/delivery-contract.md) for authorized parallel or sequential execution and integration ownership. After assembling the repair, use game-functional-verification on the original reproduction plus affected boundaries. Apply the code-review decision for code changes and required final gates; send findings to their owners and refresh affected evidence after repairs. If regression fails, return to diagnosis with new observations; do not silently expand the patch.
Unreproduced or tool-blocked defects remain explicitly unresolved. Preserve attempted conditions and next observable action. Never replace old review hashes with new hashes to make stale evidence pass.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
