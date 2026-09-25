---
name: game-bug-reproduction
description: Produce a repeatable game-defect reproduction or an honest non-reproduction record without patching the product.
---

## Input/output
Record each expectation's source (user/product contract versus current-code observation) and confirmed/proposed/delegated/unresolved state. Unsettled or conflicting expectations return to game-feature-spec; continue observations, block only dependent repairs. Collect expected/actual behavior, build, environment, entry state and attempted inputs. Output exact steps, fixture identity, frequency/attempt count, raw evidence and limitations.
Use isolated fixture/save copies and ordinary controls. Do not mutate a live account or original save to reproduce a bug. Preserve original logs and failed attempts. Reduce the sequence only while the failure remains reproducible.
For intermittent failures report both successful and unsuccessful reproduction attempts. If instrumentation is needed, describe the observation required and return to the implementation/tool owner; do not quietly patch product code.
Do not identify a cause from a symptom alone. Pass reproduction to game-bug-diagnosis. Missing tools or inability to reproduce is not evidence that no bug exists.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
