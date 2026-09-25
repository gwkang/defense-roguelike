---
name: game-workflow
description: Use when starting or resuming indie-game work to reconnect an existing run, route the request, and activate supervision before stateful or multi-stage specialist work.
---

## Responsibility
Be the game-work bootstrap and intake specialist. Preserve the user's goal, constraints and decision authority. Own run discovery and routing, not planning, product design or execution supervision.

## Bootstrap
Apply this skill before the first substantive response, question, repository inspection or other game skill for a new or resumed game request. If a dispatched specialist already has a `dispatched` context marker with parent run/task identity, follow that assignment without restarting routing.

Read the project profile's `workflowRunRegistryPath` when stateful work may exist. Reconnect one matching open run before treating the latest message as a new goal. An explicit run ID is authoritative: if it is absent from the open registry, record `not-found` and resolve that identity instead of falling back to conversation, target or goal matches. With multiple plausible matches, ask the user to select one; with a stale pointer, record `needs-reconciliation` instead of creating a duplicate. Preserve an explicit skill choice and record it as standalone or supervised according to the task shape.

Treat the latest explicit user steering as the authority cursor for the resumed request. A later instruction may resume, narrow or replace a branch that an older checkpoint marks skipped, blocked or deferred. When the current request, checkpoint and later run events disagree, pass the conflict to supervision as `needs-reconciliation`; do not infer an authorization violation from the older checkpoint alone. Identify the latest user turn or event when available, the branches it resumes, the branches it leaves deferred and the earlier decision it supersedes.

## Route
1. Read the request, relevant supplied documents and current work record. Distinguish consultation, specification, review and execution. Feature words alone do not authorize implementation.
2. Reuse an active run for corrections, status questions, answers and follow-ups. Increment its goal revision when the intended outcome changes, including an explicit resume of previously skipped or deferred work. Preserve the older decision as history and link the superseding user turn or event. Create a new run only for a genuinely separate goal.
3. Select development for new behavior, improvement for better existing experience/quality, bugfix for a violation of expected behavior. If the expected behavior is unclear, route evidence gathering or specification first; do not invent it.
4. Activate game-workflow-supervision before a specialist when work requests repository/product mutation, has dependent stages, resumes or redirects an open run, needs multiple specialists or independent verification, or contains a decision that can invalidate downstream work. Pass the selected development/improvement/bugfix flow as policy; do not create a second supervisor.
5. A simple consultation, isolated read-only review or explicitly bounded standalone artifact may finish without supervision when the routing record states why. Preserve explicit skill choice. Specification uses game-feature-spec when applicable; improvement assessment and bug reproduction use their actual specialists.

For visible UI or player-facing copy, apply the [UI change classification](../game-task-planning/references/ui-adapter.md) to the intended result, not the implementation size. Record the relevant design and copy owners or a supported reuse reason.

Use [the routing template](assets/routing-template.md) for a handoff. The router asks only when route or authority cannot be determined. After supervision begins, the supervisor owns later clarification. Ask only when an unresolved choice materially changes the outcome or authority, and present the recommendation and effect.

For supervised work, propose an initial portable capability tier from task risk and shape; do not name a concrete model. The supervisor resolves each actual dispatch using the project model-routing profile and current host capabilities.

Skills are instructions read by the executing agent, not function calls. Resolve the selected sibling's actual SKILL.md and references. Report missing dependencies without installing them. Project AGENTS.md may require this bootstrap but must not duplicate its routing procedure.

For optional project knowledge, pass configured index/policy locators during intake under the [knowledge contract](../game-task-planning/references/knowledge-contract.md). Distinguish installation-only requests from requested wiki integration using its setup/adoption rules; missing settings alone do not authorize creation, and must not silently downgrade an authorized integration to installation only.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
