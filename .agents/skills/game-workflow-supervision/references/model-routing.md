# Capability-tier model routing

Choose a capability tier from task risk and shape. Tiers are portable; concrete model IDs belong to the project model-routing profile.

| Tier | Use when |
| --- | --- |
| `highest-judgment` | A wrong decision can invalidate product direction, architecture, shared state or final integration; ambiguity or cross-stage dependencies are high. |
| `complex-execution` | The contract is settled but implementation or review needs substantial reasoning, tools or long context. |
| `balanced-execution` | Scope and checks are clear, ordinary engineering judgment is sufficient and cost still matters. |
| `high-volume` | Work is repetitive, independently checkable, low risk and benefits from throughput. |

Consider error impact, dependency depth, ambiguity, context size, verification strength and repetition/cost in that order. Use the lowest tier that still covers the failure cost. Independent review requires a separate executor; it does not automatically require a different or stronger model.

## Resolution

1. Preserve a user-specified model. If it is unavailable or the execution tool cannot override models, block that dispatch and report the exact incompatibility.
2. Otherwise read the project profile's `modelRoutingProfilePath`. Resolve the selected tier against the host's currently available models in the profile's candidate order.
3. Apply the resolved model and reasoning effort only when the dispatch tool supports explicit overrides. The current root model never changes silently.
4. If no tier candidate is available, or overrides are unsupported, keep the host-selected default and continue. Record the fallback; do not invent a model ID.

Record `capabilityTier`, `reasoningClass`, `resolvedModel`, `resolutionSource`, `overrideSupported` and `fallbackReason` for each dispatch. Use `host-default` as the resolved model label when no override is applied. Re-resolve at dispatch time because host availability may change.

The optional deterministic resolver in `scripts/resolve_model_route.py` validates a project mapping and applies these fallback rules. Its result is a dispatch input, not proof that the host actually used the model; retain the executor acknowledgement or raw runtime header as execution evidence.
