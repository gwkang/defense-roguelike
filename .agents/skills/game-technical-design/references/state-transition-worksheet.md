# State-transition worksheet

Use only where persistence, Undo or rewards make reversibility and commit behavior consequential. Extend an existing design table when sufficient; this is not a required document or a gate for ordinary tuning.

Identify each affected state's owner/allowed writer, whether it is transient or persisted, and whether Undo may restore it. Derive those choices from agreed rules; persistence alone does not determine reversibility.

For relevant actions, fill a compact table in the technical design:

| Action / precondition | State mutations / owner | Durable commit boundary | Undo restores / retains | Failure, retry and duplicate handling | Player-visible result |
| --- | --- | --- | --- | --- | --- |

Distinguish pending changes from confirmed results and identify what the actual storage contract guarantees. If an outcome depends on persistence, specify the pending/failure display and when it becomes confirmed. State what stays intact after failure and what enables retry; avoid assuming a transaction or durability guarantee the adapter lacks.

Walk a normal action and the applicable failure, duplicate/retry, interruption/recovery or Undo cases through the same fields. For an asynchronous completion arriving after Undo or a session change, specify whether it is accepted and which owner cleans up pending state. Do not fill unrelated rows merely to cover the list.

Map these cases to existing acceptance IDs and hand them to test design and the relevant rule, save, session or presentation owners. A design walkthrough is not an executed test. Unresolved reward/Undo semantics return to the feature owner; the table must not invent them.
