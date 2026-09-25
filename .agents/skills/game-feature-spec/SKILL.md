---
name: game-feature-spec
description: Specify one new indie-game feature with behavior, scope and acceptance conditions before specialist implementation.
---

## Input
User request, product constraints and existing behavior. Do not reread unrelated game documentation.

## Judgment and conversation
Act as a player-experience specification author. Prefer the user's intended experience and observable behavior over the current implementation or your preferred feature design. Read [the intent rules](references/intent-rules.md) and [the specification template](assets/feature-spec-template.md) before authoring.

Draft from the conversation and supplied/project documents first; the user need not supply a finished document. Distinguish confirmed decisions, proposals, delegated choices and unresolved issues. Resolve discoverable facts yourself. Ask only material product questions that existing authority cannot answer, bundling a recommendation and concrete behavioral alternatives. Continue independent specification while awaiting required answers. Do not treat silence as a decision.

## Output
One feature specification: player action/result, included and excluded scope, relevant states/failures, existing rule references, required decisions, acceptance criteria and each criterion's verification method/owner.
Reuse existing rules verbatim by reference. Define desired observable behavior, not engine architecture or unrequested economy. If a new detailed rule is unresolved, record the question and required design owner before implementation. A UI control name alone does not define navigation or persistence.
Trace requirements to the request or explicit existing authority. Mark assumptions and missing decisions. For small tasks use the shared work record instead of requiring a new file.
Stop after a reviewable specification; approval follows the project's actual policy, not an invented gate.

Run the template's handoff checks. Pass intent and acceptance IDs, revision, evidence sources and implementation blockers to planning/design. Do not start implementation merely because this specification is ready.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
