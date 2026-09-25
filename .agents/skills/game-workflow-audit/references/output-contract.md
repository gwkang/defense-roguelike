# Workflow audit output contract

Return `workflow-audit@1` through the common artifact envelope. Missing evidence remains unknown; do not fill it from inference.

## Audit identity and observed path

- audit event/trigger, supervisor dispatch and recorded benefit-versus-cost reason
- run/task/attempt, candidate and checkpoint revisions
- actual producer skills and revisions, adjacent producer-to-consumer handoffs, result and raw-evidence locators
- included and excluded scope, time/token/slot budget, stop condition and actual cost when observable
- limitations, stale inputs and unavailable evidence

## Findings

For each finding record:

| Field | Required content |
| --- | --- |
| ID and class | One of `confirmed-defect`, `recording-gap`, `operational-risk`, `efficiency-loss` |
| Observation and evidence | Current observable fact, exact locator/revision and affected task or handoff |
| Impact | Product quality, decision reliability, rework, delay, token/time/slot cost, or other bounded effect; do not invent measurements |
| Cause layer and confidence | Exactly one leading layer plus alternatives: `product`, `environment-tooling`, `evidence-recording`, `execution-handoff`, or `skill-contract`; state confirmed or hypothesis and what would distinguish alternatives |
| Existing contract comparison | Consumed rule locator and whether it was absent, ambiguous, violated, or sufficient but unrelated |
| Owner and disposition | Product/tool/record/executor/supervisor/skill owner; `observe-only`, `return-to-owner`, or `limited-improvement-proposal` |

Classification means:

- `confirmed-defect`: current evidence demonstrates a product or contract failure.
- `recording-gap`: authority, identity, result or task state and its shared record disagree or are incomplete; this alone is not a product failure or unauthorized action.
- `operational-risk`: a plausible future failure without current failure evidence.
- `efficiency-loss`: current evidence shows avoidable rework, waiting, repeated context, duplicate checks or resource use; report actual observations separately from estimated cost.

One observation may have related effects, but do not duplicate it under multiple classes to inflate severity. Include material non-findings when they prevent a product, executor, or skill from being blamed without evidence.

## Limited-improvement eligibility

For each possible skill change return one eligibility state: `not-eligible`, `observe-for-repeat`, or `eligible-proposal`. An eligible proposal requires all of:

- exact owning skill and failing contract boundary
- evidence that the current contract cannot adequately prevent or detect the issue, rather than an existing rule merely being ignored
- one severe evidenced failure or a repeated same-cause lineage
- smallest rule/reference change capable of addressing it
- explicit files or behavior that must not change
- original-case detection check and an unrelated compatible burden/regression check
- expected benefit, added time/token/slot cost, false-positive or overconstraint risk, and a removal/rollback signal

The proposal is advice, not authority. It creates no task, gate, edit, approval, retry, or expansion of scope. Record the required decision owner for any follow-up.

## Overall return

State the audit completion status, findings by class, whether any limited improvement is eligible, exhausted budget or stop reason, the actual audit time/token/slot cost when observable, and the exact next decision owner; when there are no findings or eligible changes, return explicit `no-change`. Do not give the audited run a product-quality or completion verdict.

## User-facing report

The overall supervisor presents a concise report in the user's language when returning audit results and again when an authorized improvement is delivered. The auditor supplies observations and proposals; only the supervisor combines them with actual author and verifier results. Use plain explanations before internal IDs and link the relevant files and evidence. Reuse the existing run/result record; no separate report file or additional approval gate is required.

Lead with the scope and its current state: proposal only, edited awaiting verification, verified and applied, no change, or inconclusive. In Korean use `제안만 있음`, `수정 완료 · 검증 대기`, `검증 통과 · 적용 완료`, `변경 없음`, or `판단 보류`. If verification fails, say `검증 실패 · 수리 필요` and identify the remaining defect. State each item's status separately when outcomes differ. Findings that require an owner response remain visible even if no skill change is eligible; `no-change` describes edits, not absence of problems.

For each material finding or change, show a compact table or short paragraphs in this order:
- **발견한 문제 / 이유:** observed problem, evidence and why a rule change is needed; distinguish confirmed causes from hypotheses.
- **변경 전 → 변경 후:** explain the practical difference and link changed files. For an unimplemented proposal label the latter `제안 내용 · 미반영`; never describe it as applied. When nothing changed, say so without inventing a before/after pair.
- **검증:** actual checks and results, evidence links, and any untested or failed criteria. Keep expected benefit separate from measured improvement.
- **적용 범위 / 남은 사항:** local installation, commit, push and shared-source publication status when relevant, plus unresolved work and observable audit cost (unknown values stay unknown).
- **확인 요청:** include only a concrete decision still requiring the user's input, with its reason and recommendation. Otherwise say `확인 요청 없음` or omit this field; do not request approval for already authorized work.

Keep the main report readable without opening links. Summarize routine checks and attach detailed evidence through links; do not dump hashes, full logs or internal envelopes into the user-facing summary.
