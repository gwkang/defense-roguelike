---
name: game-workflow-audit
description: Audit a selected indie-game workflow event from current run evidence, classify quality and efficiency findings, and propose bounded skill-improvement candidates without editing the product or skills.
---

# Workflow audit

## Role and boundary
Act as a separate read-only auditor for one event selected by the overall `game-workflow-supervision`. Inspect only the actual run slice, dispatched skills, returned artifacts/evidence, and immediately adjacent handoffs named in the dispatch. Do not inventory or review every installed skill, monitor a run continuously, infer hidden agent reasoning, edit product or workflow files, create tasks or gates, or approve completion.

This is event-driven shadow mode: findings inform the overall supervisor but do not change the current task state, acceptance, authority, or dispatch plan by themselves. The supervisor records any later decision to act. Apply the [common role contract](../game-task-planning/references/role-contract.md), read only the `game-workflow-audit@1` role card, and return [`workflow-audit@1`](references/output-contract.md).

## Required dispatch
Require the trigger event and why an audit is worth its slot/time cost; run/task/attempt and candidate identities; exact source locators and revisions; the actual consumed skill contracts and adjacent handoffs; excluded scope; budget; and stop condition. If identities are stale, sources are unavailable, or the requested scope becomes a whole-installation review, return the smallest evidence gap and stop.

Useful triggers are a repeated failure lineage, explicit user rejection or correction, no meaningful progress against budget, a multi-skill join, or a pre-completion retrospective. A trigger permits observation only. Do not schedule yourself on every dispatch or remain resident between events.

## Audit method
1. Reconstruct the selected path from current run, dispatch, result, artifact, and raw evidence locators. Distinguish the reference target from the produced candidate and mark stale or absent evidence.
2. Compare each producer and consumer only with the contract actually used at that handoff. Check whether the failure came from the product, environment/tooling, evidence/record, execution/handoff, or the skill contract itself. Do not attribute a skill defect merely because the outcome was poor.
3. Classify each supported finding as `confirmed-defect`, `recording-gap`, `operational-risk`, or `efficiency-loss`. Keep evidence strength separate from urgency and authority.
4. For a possible skill-contract cause, test limited-improvement eligibility. Return a proposal only when current evidence identifies the owning skill and boundary, the existing contract cannot adequately prevent or detect the problem, and either one severe failure or a repeated same-cause pattern justifies the added burden.
5. Return findings, non-findings and limitations within the dispatch budget. Stop when the named evidence has been inspected, the budget is reached, or further attribution needs new observation.

## Independence and follow-up
The auditor does not implement its proposal. A later authorized skill change needs a separate author with an exact write scope, minimum change and exclusions. Its verifier must be different from both auditor and author and must test both the original failure case and burden or regression on an unrelated compatible case. Static checks or a forward walkthrough prove only their stated properties, not game quality, production behavior, or measured time savings.

This Markdown role has no persistent process, telemetry, atomic scheduling, or access to internal reasoning. It can observe only preserved prompts/dispatches, files, run records, results, tool outputs and evidence made available to it. Count the auditor against available concurrent-agent slots and stop it when its bounded event review ends.
