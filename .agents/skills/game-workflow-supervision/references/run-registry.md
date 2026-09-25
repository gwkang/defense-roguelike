# Run registry contract

The project profile supplies `workflowRunRegistryPath`. The registry contains only pointers used to reconnect open work; the linked run record owns decisions, questions, tasks and evidence.

The router reads and matches the registry. Once supervision starts, only the overall supervisor changes a run record or its pointer. Write the run record first, then atomically update the registry. Closing a run sets `completed` or `cancelled`; do not delete history merely to avoid a match.

An explicit run ID is authoritative. Match only that ID; when no open pointer has it, return `not-found` and resolve the requested identity without falling back to conversation, target or goal matches. Without an explicit ID, match conversation identity, exact target paths and stable goal keys in that order. Zero matches means a new run may be created. One means resume. Equal best matches require user selection. A matching pointer whose record is absent returns `needs-reconciliation`; do not silently replace it.

The registry script validates structure and provides deterministic matching. It does not infer user intent, lock files, create run records or grant authority.
