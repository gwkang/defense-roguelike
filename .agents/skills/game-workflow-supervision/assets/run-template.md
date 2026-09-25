# Workflow run

Rules: required fields must be populated or explicitly not-applicable with reasons. Record real execution, not hypothetical success. Link existing sources rather than copy their authority. Overall supervisor is the only shared-record writer. Results can live in task-local files using the envelope below.

## Identity
- Run ID / plan revision / overall executor:
- Run status / goal revision / prior goal revision:
- Registry locator / conversation key if available / match basis:
- Original request / authority / intent / selected entry flow:
- Workspace / target / existing changes to preserve:
- Skill and input paths/revisions:
- Resolved conversation/artifact language and source/override:
- Mode / isolation or confirmed single writer / resource limits / model-routing profile:
- Repair limit / relevant project commands and review policy:

## Clarification
| Decision ID | Known evidence and current recommendation | Alternatives and player/product effect | Owner | Affected tasks | State |
| --- | --- | --- | --- | --- | --- |

Use `clear`, `needs-clarification` or `resolved`. Silence does not resolve a decision. Ask one question at a time unless the decisions are inseparable, and continue only unaffected authorized tasks.

## Current checkpoint

Keep this short; update it at dispatch/return/repair and before context compaction. Link history rather than copying it. On resume verify it against current files, input identities and active workers before dispatch.

- Goal revision / authorized outcome / current slice and acceptance IDs:
- Authority cursor: latest explicit user turn or event / superseded decision IDs / resumed branches / still-deferred branches:
- Checkpoint revision or last-incorporated event ID:
- Current candidate and relevant input revisions / target runtime and reference roles:
- Current candidate digest / drift from the last frozen candidate:
- Active task IDs, owners and stable read/write/resource boundaries:
- Current verdict and evidence locators / leading blocker and exact next owner/action:
- Structural-design trigger: `required`, `not-required` or `unresolved` / owner, rationale and decision revision:
- Formal UI UX prerequisite: affected screen/task IDs / resolved decision ID and revision plus separate verification, or exact compatible approved reuse and unchanged-scope evidence / blocked consumers when missing:
- Failure-lineage IDs with remaining attempts / run time-token budget and progress since last checkpoint:
- Last reconciliation time / uncertain or stale facts:

## Tasks
| Task ID | Skill/owner/supervisor | Inputs/revisions | Output template/rules/location | Predecessors/result conditions | Read/write/resources | Capability tier/reasoning/resolution/fallback | Integration owner | State/attempt/executor/model evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |

Each dispatch brief links one task row and states the observable result, acceptance IDs, exact required inputs/revisions, environment, read/write/excluded scope, check, result locator, budget and stop condition. Send those fields and only necessary context to the worker; do not paste this entire record. Compatible outputs may share one separate verifier dispatch on a stable candidate, while each artifact keeps its own verdict.

## Artifact verification
Use [the bounded verification rules](../../game-task-planning/references/verification-scope.md). Each selected artifact has a row or an inline record with the same fields. Freeze before checking; do not add criteria during repair. Producer and verifier executor IDs must differ. Author self-checks do not close verification; producer repairs and the separate verifier rechecks.

| Artifact/revision | Producer/separate verifier executor IDs | Scope source; included criteria/pass conditions; exclusions | Necessary reads; permitted repair paths/resources | Checks/evidence | Repair owner/budget/attempt | Verdict/current evidence |
| --- | --- | --- | --- | --- | --- | --- |

## Repair and deferred observations
| Finding/evidence | Artifact/criterion or out-of-scope reason | Repair owner/allowed change or deferred only | Lineage ID, remaining budget, attempt/hypothesis | Affected rechecks/result | Blocker/minimum scope proposal if necessary |
| --- | --- | --- | --- | --- | --- |

Out-of-scope observations create no task or gate. A necessary change beyond authority blocks only dependent criteria pending explicit scope authorization. Keep unchanged criteria and still-valid evidence across retries.

For audits and status reports, label each finding `confirmed-defect`, `recording-gap`, `operational-risk` or `efficiency-loss`. An older checkpoint conflicting with later explicit user steering is a recording gap pending reconciliation, not evidence of unauthorized work. Candidate movement inside an owned active attempt is normal; only affected evidence becomes stale until the candidate is frozen and rechecked. A finding alone creates no task, gate, edit, retry or blocker.

## Optional workflow audit

Use only for an event-driven shadow audit selected under the supervision contract. Omit this section when no audit is justified.

| Audit ID/event | Trigger and expected benefit | Run/task/candidate and source revisions | Actual consumed skills and adjacent handoffs | Read/excluded scope | Time/token/slot budget and stop condition | Auditor executor / state / actual cost | Output locator |
| --- | --- | --- | --- | --- | --- | --- | --- |

| Finding ID/class | Observation/evidence | Leading cause layer/confidence/alternatives | Existing contract comparison | Impact | Owner/disposition | Limited-improvement eligibility/proposal locator |
| --- | --- | --- | --- | --- | --- | --- |

Cause layer is one of `product`, `environment-tooling`, `evidence-recording`, `execution-handoff` or `skill-contract`. Disposition is `observe-only`, `return-to-owner` or `limited-improvement-proposal`. A proposal remains advice until a separately authorized authoring task exists. Record auditor, author and verifier as different executor IDs; the verifier checks the original case and an unrelated compatible burden/regression case. Do not use static or walkthrough evidence as proof of product quality or realized time savings.

## Supervisor assignments
| Assignment/plan revision | Executor/role card | Task set and read/write/resource boundary | Remaining shared retry budget | Previous owner stopped / retirement / activation evidence | Inherited results and input/criterion validity |
| --- | --- | --- | --- | --- | --- |

## Decisions and events
| Event ID | Task/attempt/dispatch | Observation and evidence | Decision/authority | Affected work and next action |
| --- | --- | --- | --- | --- |

Use pending/ready/running/completed/failed/blocked/cancelled/skipped for task execution, pass/fail/inconclusive/not-applicable for verdict, current/stale/unknown for evidence. Run control may also be `needs-clarification` or `needs-reconciliation`. State explicitly when a dispatch is uncertain. A completed check with fail does not enable its pass branch.

## Worker result envelope
- Run / task / attempt / dispatch / actual executor / acknowledged model:
- Capability tier / reasoning class / resolution source / override support / fallback reason:
- Consumed inputs and revisions:
- Produced artifacts and [type/version envelope](../../game-task-planning/references/artifact-contract.md), format/rule locator/revision, consumer:
- Role card ID/version; decision states/source IDs; selected reference card/decision/verification links (or no-reference reason):
- Changed paths / candidate identity including relevant dirty content:
- Checks: command or observation, environment, result, raw evidence locator:
- Verdict / evidence validity / limitations:
- Verification contract / in-scope failing criterion IDs / repair attempt and affected rechecks:
- Defects, return owner and next required action:
- Interim context handoff, when unfinished: consumed input revisions; candidate/changed paths; completed checks and raw locators; current blocker; next action and remaining budget. This is not a completed result or approval.
- Deferred out-of-scope observations (no automatic work or gate):

## Optional knowledge integration
When enabled, record policy/index locators, selected page scope, required/optional/not-applicable classification and authority, writer, sources/revisions, and applied/no-change/deferred/blocked outcome with verification evidence. Reuse Tasks and Artifact verification rows rather than duplicate them. A deferred required update remains unmet.

## Acceptance coverage
| Criterion ID | Intent/source | Artifact/candidate | Scenario/result/evidence | Review/decision if required | Current status |
| --- | --- | --- | --- | --- | --- |

## Final report
- Status and fulfilled scope:
- Current candidate and artifacts:
- Verification/review results and limitations:
- Unresolved or excluded scope with reason:
- Next action for blocked/failed work:

Completion checks: all selected required outputs have their templates/rules and usable content; all in-scope criteria have current sufficient evidence; required gates and decisions are satisfied; no stale/late result supplies acceptance. A field-count check does not establish quality. Persist this report without declaring external publication or installation that did not occur.
