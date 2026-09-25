---
name: game-technical-design
description: Resolve consequential game architecture, algorithm, data and lifecycle decisions into an implementable, verifiable design grounded in current code. Does not implement it.
---

## Scope
Use agreed requirements or diagnosis, acceptance IDs and the target project profile. Own the technical design; leave product decisions, task scheduling, code and test execution to their owners. Reuse adequate contracts for small repairs; important decisions within one module can still need design.

## Design
1. **Inspect:** trace relevant callers, state writers, consumers and cleanup in current code and tests. Cite paths/symbols and source revision or working-tree state. Identify the failure or constraint and reusable structure. Separate observations, requirements and assumptions; state when source evidence is unavailable.
2. **Choose:** prefer the smallest sufficient change. For consequential choices, compare a credible alternative on relevant correctness, complexity, cost and verification tradeoffs. Do not manufacture alternatives for obvious repairs or invent measurements/API guarantees. Mark evidence-dependent decisions provisional.
   For affected class/function boundaries, use the [shared coding decisions](../game-task-planning/references/delivery-contract.md#implementation-completion): responsibility, invariant protection, dependencies and justified complexity; leave routine local choices to implementers.
3. **Specify:** settle the changed data/invariants, core algorithm, ownership, interfaces and state transitions. Include boundary inputs, ordering, commit points, failure/retry and compatibility where affected. Name actual owners and allowed writers; keep semantic reward/damage decisions in the rule owner. For player-facing or presentation code, distinguish orchestration, view/component state, live-data projection, input, navigation and effects where they cross the changed boundary; do not infer a mandatory architecture when the existing contract is adequate. Use the target's engine, coordinates, units and clock. Leave routine coding choices to implementers.
4. **Challenge:** walk concrete normal and risk-selected counterexamples through the design. Map each acceptance ID to a mechanism and observable result; check producer/consumer agreement and invariant preservation. For discarded async work, specify who releases its reservation, how retry becomes possible, and why old cleanup cannot clear newer work. A walkthrough is not an executed test.

When persistence, Undo or reward changes need an explicit reversible/durable boundary, use the optional [state-transition worksheet](references/state-transition-worksheet.md). Reuse an adequate existing table; ordinary tuning does not require this worksheet.

When the proposed change is a bootstrap, adapter, migration seam or other provisional structure, define its permitted consumers, forbidden expansion, owner, replacement or promotion criteria and cleanup/integration trigger. Passing focused behavior checks does not by itself promote provisional structure into the maintained architecture.

Read [runtime concurrency](references/runtime-concurrency.md) only for worker/job/thread or shared-state concurrency changes. Ordinary async I/O does not require multithreading.

## Write
Use [the template](assets/technical-design-template.md) when authoring a design artifact. Small repairs can use a few paragraphs in the existing record. Keep the review body understandable on its own; link essential technical detail without duplicating contracts. Preserve important risks in the opening. Do not copy this checklist into the output.

Apply [the language contract](../game-project-profile/references/artifact-language.md); preserve identifiers and raw evidence.

## Handoff
Ready means consequential decisions are supported, contracts agree and outcomes are observable. Name unresolved issues, their owners and blocked portions; return missing game semantics to the feature owner and continue unaffected work. Readiness does not create an approval gate.

Pass design/input revisions, acceptance IDs, affected paths/consumers, owners and dependency order to game-task-planning and implementers. Pass scenarios and regression boundaries to game-test-design; harness work and execution remain with their respective owners. A revision identifies downstream work requiring recheck.

Before handoff, check that a human can understand the change, rationale, risks and decisions from the review body, and an implementer can use the details without redesigning consequential parts. Keep both consistent with the evidence.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
