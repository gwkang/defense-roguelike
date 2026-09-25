---
name: indie-game-development
description: Coordinate a small indie-game feature from an existing request to verified delivery; reuse specialized UI skills for screen work.
---

## Inputs and output
Read the request, routing record, relevant project profile fields, existing feature artifacts and working-tree constraints. Own development flow policy, not specialist decisions. Use the already active [game-workflow-supervision](../game-workflow-supervision/SKILL.md), or activate it when the routed request requires supervision. The procedure below supplies its development policy; never create a second supervisor or route back to game-workflow.

## Execute
1. Reuse an adequate feature specification; otherwise apply game-feature-spec. Do not require a prototype stage.
2. Use game-technical-design when consequential structural, algorithmic, data or lifecycle decisions lack an adequate existing design, even within one module. Reuse sufficient contracts for local edits. Select only affected owners using the routing in game-task-planning. UI work uses the available existing UI chain with its actual required inputs. Other specialties require an available matching skill; report a missing capability rather than pretending the bundle contains it.
3. Use game-task-planning for dependencies; a small change can keep its order in the work record. Use game-test-design when acceptance scenarios need definition and game-test-infrastructure only when shared tooling needs implementation. Individual implementers own local regression tests.
4. Follow [the delivery contract](../game-task-planning/references/delivery-contract.md) for execution: use authorized parallel workers for suitable independent tasks, otherwise switch roles sequentially. Honor UI stop/approval rules and join results through the assigned integration owner.
5. Use the planner's recorded code-impact decision before deferring visual polish. If structure-first is needed, settle only the affected player-flow, input, state or layout contract early. When polish is deferrable, assemble a playable target-runtime slice with a minimal functional interface and verify the complete player loop before final polish. Reuse an existing playable interface and still-valid evidence where they cover the slice; do not create a replacement temporary screen solely for this stage. Use the playable-functional mode of game-ui-implementation only for needed new temporary screen code; core-only tests or a browser preview do not close this gate.
6. Then complete requested visual design and polish through the formal UI chain. If the selected design would replace the planned interface structure or cause substantial code rework, stop treating it as late polish and replan the affected implementation before continuing. Recheck affected functional behavior if polish changes interaction, input geometry, state meaning or shared dependencies; verify visual fidelity on the final runtime candidate. Do not require final art approval to begin the earlier playable slice, and do not call the polished product complete merely because the functional slice passed.
7. Run game-functional-verification on the assembled candidate, apply the delivery contract's code-review decision and required final gates, and resolve findings through their owners. Mark completion only against current evidence and required acceptance decisions.

Record request, scope, selected roles, artifacts/revisions, evidence and unresolved items. Reopen dependent evidence when inputs change. Preparation for release does not authorize publication.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
