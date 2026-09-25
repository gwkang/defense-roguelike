# Feature specification

Use the linked intent rules. Fill applicable fields or state why not applicable. A small change may use this structure inside the work record. Do not leave placeholders in an artifact claimed ready.

## Identity and authority
- Artifact ID / revision / author task-attempt:
- Target / input revisions and source locators:
- Artifact language and source (or inherited run reference):
- Original user goal:
- Status: draft | partially-ready | ready; ready scope and blocked scope:

## Problem and experience
- Player / situation / problem / reason:
- Desired experience and success scene:
- Priorities, constraints and exclusions:

## Intent decisions
| Intent ID | Behavior or constraint | confirmed/proposed/delegated/unresolved | Source and delegation boundary | Selected outcome/reason or needed decision |
| --- | --- | --- | --- | --- |

## Behavior and boundaries
| Behavior ID | Intent IDs | Preconditions/state | Trigger/action | Observable result | Failure/interruption/recovery | Preserved behavior |
| --- | --- | --- | --- | --- | --- | --- |

## Acceptance
| Criterion ID | Intent/behavior IDs | Scenario and counterexample | Expected observation | Method/fixture | Verification owner |
| --- | --- | --- | --- | --- | --- |

## Handoff
- Material unresolved questions, recommendation/alternatives and affected work:
- Next consumers and required inputs:
- Changes from previous revision and affected criteria:
- Checks and limitations:

Handoff checks: every in-scope intent has observable coverage; all constraints survive; proposals are not presented as confirmed; required open decisions block only dependent implementation; methods and owners are concrete enough for the next role; existing rules are referenced rather than independently rewritten. A ready spec does not authorize implementation or replace required product decisions.
