---
name: game-workflow-supervision
description: Supervise a routed stateful or multi-stage indie-game run from clarification and planning through specialist handoffs, repair, integration and evidence-based completion.
---

## Role and inputs
The main agent is the one overall supervisor. Own the run registry, execution record, clarification state and control decisions; specialists own product documents, code and quality verdicts. Read the routing decision, selected flow, request authority, project profile and any current plan. A plan may be pending during specification or clarification. Use [execution rules](references/execution-supervision.md), [run registry contract](references/run-registry.md) and [the run template](assets/run-template.md). When a dispatch tool can select a model, also apply [capability-tier model routing](references/model-routing.md).

Ask game-task-planning for missing dependencies, scopes and output contracts. Do not substitute your architectural preference for a specialist decision. Input/acceptance uncertainty returns to its owner. Existing UI work follows its available skills and actual approval/coverage contracts.

Before dispatching implementation, require a current `game-technical-design` decision when the work changes consequential responsibility, state ownership, shared interfaces, lifecycle, integration boundaries, or promotes provisional structure into a maintained product baseline. The supervisor identifies that a design decision is missing and records its blocked consumers; the technical designer owns the decision. An exception, bootstrap, schedule pressure or missing downstream artifact does not transfer that authority to supervision.

## Clarify and resume
Reuse the routed run and increment goal revision when user steering changes the intended result. Before classifying resumed work as authorized or out of scope, reconcile three sources: the current checkpoint, explicit user instructions after that checkpoint, and later decisions/events or actual task state. A later explicit instruction can resume a skipped or deferred branch without erasing the old decision. Record its authority cursor, superseded decision, resumed branches and still-deferred branches before the next affected mutation dispatch.

Use `authorized-current` when the latest instruction and record agree, `needs-reconciliation` when later authority or task state is known but the shared record has not caught up, and `unauthorized` only when the latest applicable user authority has been checked and the work still exceeds it. Do not report a policy violation from an older checkpoint alone. Ask only material questions that project evidence and existing authority cannot resolve. Record the recommendation, alternatives, affected tasks and `needs-clarification`; silence is not approval. Ask one question at a time unless decisions are inseparable. Continue independent authorized work while dependent tasks wait. Multiple active-run matches return to the user for selection.

## Execute
Select only ready tasks. Perform bounded roles sequentially where appropriate. For genuinely independent work, delegate specialist tasks when applicable authorization and host tools permit; keep the actual executor and scope in the record. Separate reviewers from authors when independence is required. Do not claim role switching is independent review.

Before dispatch, choose one observable result and its smallest sufficient verification slice. Maintain the run template's current checkpoint for the overall run; hand workers a bounded brief instead of the conversation or full run history. Apply the task-sizing, context-handoff and no-progress rules in [execution supervision](references/execution-supervision.md). A new task or stage does not reset the run's failure lineage or resource budget.

Collect each result, validate its input/candidate identity and template, route defects to their owners, and join selected branches on one candidate. Read [the shared delivery contract](../game-task-planning/references/delivery-contract.md) for write/read isolation, integration, review and final gates. Follow the current entry flow's failure routes. Do not stop at a worker's success statement.

For selected workflow-quality events, the overall supervisor may dispatch a separate read-only [`game-workflow-audit`](../game-workflow-audit/SKILL.md) in shadow mode. Use only the event triggers, bounded evidence path, cost record and independence rules in [execution supervision](references/execution-supervision.md). An audit finding is advice: it does not create a task, gate, edit, retry or completion verdict. Any accepted skill improvement is a separately authorized, narrowly scoped authoring task followed by a verifier different from both auditor and author.

At dispatch, repair and join, compare actual visible/copy changes with the recorded [UI classification](../game-task-planning/references/ui-adapter.md). Return new visual composition or changed meaning to its design/copy owner and retain only still-valid evidence.

For a formal UI screen, also inspect the run's `UX prerequisite` before dispatching affected art-direction decisions, new component structure, formal screen-spec, mockup, or their downstream handoff. Require an exact resolved UX decision ID/revision and separate verification, or an exact approved compatible-reuse decision with its unchanged-scope evidence. If absent, stale or contradicted by current screen content/target/interaction, record the affected consumers as blocked and route a bounded `game-ui-ux-design` task; do not promote an older mockup verdict by writing a new prerequisite after the fact. Recheck the prerequisite at join and after changes to task flow, hierarchy, feedback or dense-content layout. Keep exploratory drafts, playable functional UI and compatible pure styling/technical repairs on their documented paths without granting them formal UI readiness.

Minimize human intervention: reuse decisions, inspect facts, resolve ordinary scoped choices internally, and continue unaffected work. Ask only for material product decisions or genuinely missing authority after preparing a concrete result/recommendation. Do not ask permission at every stage.

For enabled project knowledge or requested integration, apply the [knowledge contract](../game-task-planning/references/knowledge-contract.md): coordinate authorized setup when needed, classify required/optional updates within authority, assign bounded maintenance, and include required verified deltas before final candidate freeze. Keep installation status separate from integration acceptance; disabled or missing settings do not satisfy a requested integration.

When reporting workflow audit results or delivering an authorized skill improvement, use the [user-facing report contract](../game-workflow-audit/references/output-contract.md#user-facing-report). Reconcile proposed changes with actual edits and independent verification before stating their status; provide file links and understandable before/after effects in the final response.

## Capability boundary
This version is an instruction-driven supervisor with a Markdown run record, not the planned transactional graph engine. It provides no atomic locks, cross-run reservation, automatic crash recovery or persistent background monitoring. A workflow auditor is likewise a bounded agent call, not a resident monitor or observer of internal reasoning. Use a confirmed single-writer workspace or isolation. If activity ownership is uncertain, block affected writes until reconciled. Record unsupported automation instead of simulating guarantees.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
