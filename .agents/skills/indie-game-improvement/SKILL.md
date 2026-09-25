---
name: indie-game-improvement
description: Coordinate an improvement to existing game behavior or quality using a recorded baseline and comparison.
---

## Inputs and output
Require the routing record, existing result, user goal and affected target. Own improvement flow policy and comparison requirements. Use the already active [game-workflow-supervision](../game-workflow-supervision/SKILL.md), or activate it when the routed request requires supervision; never create a second supervisor or route back to game-workflow.

## Execute
Apply game-improvement-assessment unless equivalent current evidence exists. Require intent/source IDs and decision states; implementation consumes only confirmed choices or an authorized delegated selection, never a proposal or unresolved goal. Preserve a baseline with build, fixture, environment and evaluation criteria. Send confirmed expectation violations through indie-game-bugfix without converting all improvements into defects.
For performance questions use game-performance-profiling to establish comparable evidence before choosing an optimization owner. Select the implementation owner using game-task-planning; UI changes use existing UI specialists. Use game-technical-design for unresolved consequential structural, algorithmic, data or lifecycle decisions, reusing adequate existing contracts for local edits; use game-test-design for missing comparison/regression scenarios. If audio or another required specialty is unavailable, identify that prerequisite and finish only unaffected work.
For difficulty, reward, price or pacing experiments, use [balance experiments](../game-improvement-assessment/references/balance-experiments.md) to carry the assessed hypothesis, candidate values and playtest plan through implementation and comparison. Reuse the existing assessment record.
Follow [the delivery contract](../game-task-planning/references/delivery-contract.md) for authorized parallel or sequential execution, integration ownership and final-candidate checks. After assembling the specialist changes, compare identical relevant conditions and use game-functional-verification for preserved behavior. Apply the code-review decision for code changes; return findings to their owners and refresh affected comparison/review evidence after repairs. Report improvement, regression, inconclusive result and tradeoff separately. Do not claim numerical improvement from unmatched environments or aesthetic improvement without stated criteria.
Stop at required product decisions; save baseline and next step for resumption. Do not add features discovered during diagnosis without scope authority.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
