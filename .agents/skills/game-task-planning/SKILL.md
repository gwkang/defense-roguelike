---
name: game-task-planning
description: Break an agreed indie-game change into a small dependency-ordered set of specialist tasks and verification checkpoints.
---

## Input/output
Require scope, available specialist contracts and existing artifacts. Produce tasks with owner, input revisions, output, dependencies, acceptance evidence and completion state.
For supervised runs, use the Tasks and Acceptance coverage sections of [the run template](../game-workflow-supervision/assets/run-template.md). Every selected output needs a real template and rules; have its specialist define missing scoped formats before production. Planning must preserve intent and acceptance IDs, identify unresolved decisions blocking implementation, and hand off to the supervisor without dispatching workers itself.
For each implementation slice, record whether current responsibility, state ownership, shared interfaces and lifecycle contracts remain valid. Select `game-technical-design` before implementation when a consequential decision in those areas is missing, when a readiness exception would create maintained product structure, or when provisional code may become a shared baseline. Link the design revision and affected consumers; do not let a supervisor, planner or nearest implementation role supply the missing architecture. Do not require a design artifact for routine local choices that preserve an adequate existing contract.
Choose only necessary roles. Missing skills are explicit prerequisites, not names to invent and execute. Small changes need only a short ordered list in the work record. Do not create a feature-sized document set for a local repair. Define each task by one observable outcome, accountable owner, bounded inputs/write scope, consumer and pass condition. Split only when prerequisites, ownership/resources or independently testable results require it; combine compatible small edits that would otherwise add handoffs without a decision. Estimate a proportional effort/context budget and stop condition for each slice. Reuse existing approved outputs that satisfy the current input contract instead of producing new documents.
Assign one writer per shared artifact. Separate test infrastructure from test execution. Identify UI approval stops and resumption inputs. Recompute only affected downstream work when a dependency changes. Record changed input -> affected consumers/criteria -> retained or invalidated evidence; preserve independent results. Plan a shared failure-lineage budget so renaming a task or moving to another stage cannot restart the same repair cycle.
Do not rewrite product requirements, decide specialist output, install tools or start parallel agents just because tasks are independent.

Read [the delivery contract](references/delivery-contract.md) when planning execution and completion. Name cross-module test designers, code writers and executors, and the owner of the assembled candidate. For potentially parallel work record write paths, relevant read/verification scope, exclusive resources, input revisions and the join owner. Plan isolation or waiting when a check reads an active writer's inputs; the entry workflow dispatches only when authorized. Planning owns this assignment, not worker execution or specialist implementation.

## Select by owned state or artifact
Check each selected skill's availability and actual inputs. This table covers the implemented programming roles; it does not make every role a required stage.

| Need | Owner |
| --- | --- |
| Evidence-backed implementation approach, data/algorithm design and state/interface/lifecycle contracts | game-technical-design |
| Domain rules and semantic outcomes | game-rule-implementation |
| Device input to commands | game-input-implementation |
| Position and collision response | game-movement-implementation |
| Runtime observation and camera control | game-camera-implementation |
| Session transitions and shared pause | game-session-implementation |
| Resource acquisition, handles and release | game-content-loading |
| Serialization, persistence and migration | game-save-implementation |
| External SDK/service adapter | game-platform-integration |
| Measurements and bottleneck evidence | game-performance-profiling |
| Local build candidate and manifest | game-build-packaging |
| Scenarios and observable expectations | game-test-design |
| Shared harness, fixtures and diagnostic tools | game-test-infrastructure |
| Test execution and functional verdict | game-functional-verification |
| Read-only technical findings | game-code-review |

For gameplay development, decide whether final visual polish can follow a playable target-runtime slice without substantial UI code rework. Compare the intended design and current/temporary interface across player flow and screen partition, input semantics and hit areas, state/data ownership, responsive structure, and component/asset/motion technology. Defer polish only when these interfaces can remain stable and later work is mainly presentation. If visual direction and structural constraints are still unselected, record the assumptions and keep the low-code-impact decision unresolved until the affected structure is decided; a runtime probe cannot predict an unconstrained future design. If a consequential structure change is likely, settle only that affected screen/interaction contract before the playable slice; leave colors, typography and other separable appearance for later. If impact is unknown, use one bounded representative target-runtime probe, then decide; if it remains unknown, settle the affected structure before deferring polish. Do not require a full formal mockup merely to decide. Record the decision and evidence in the existing task/acceptance record, and revisit it when new design evidence changes the expected code impact.

When polish is deferrable, plan approved rules and interactions, a minimal functional interface, then end-to-end functional verification before final visual polish. A formal mockup, catalog or asset packet is not a prerequisite for that functional slice; final UI production retains its own gates. If polish later changes behavior, input geometry, state meaning or shared dependencies, reopen the affected functional checks.

UI work uses this bundle's integrated UI chain and its approval/coverage contracts. For early screen feedback and bounded revisions, plan the [editable draft and impact-based path](references/ui-fast-iteration.md); do not make every aesthetic decision a prerequisite for an exploratory screen. Audio, art, animation, AI, navigation and other specialists must be checked separately; do not assign their production work to the nearest programming role. Do not select build packaging unless a candidate package is part of the requested outcome.

For each selected formal UI screen, record a `UX prerequisite` in its task row: either the current resolved `game-ui-ux-design` decision ID/revision, scope and separate verification, or an exact previously approved UX decision with evidence that the current task flow, hierarchy, feedback, content density, target and input paths remain compatible. If neither exists, add a bounded UX-design task as predecessor of affected new component structure, formal screen specification and formal mockup; mark those consumers blocked, not ready. Route changed product behavior to its owner before UX resolution. Exploratory drafts may use provisional framing and a playable functional interface may proceed on its agreed functional/input contract; neither is a resolved formal UX decision. Pure styling or technical repair may retain a compatible decision without repeating UX work. Re-evaluate only affected consumers when the UX revision or underlying screen inputs change.

## Required contracts
Apply [role, output, language and independent verification rules](references/role-contract.md) even for direct invocation. Read only your role card and output type.
