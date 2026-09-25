# Runtime concurrency contract

Read only when moving work into a thread, worker or job system, or changing a shared-state concurrency boundary. Async I/O does not automatically require multithreading. Keep a sequential implementation when measured benefits do not justify parallel coordination.

Define the work unit and its executor from the project's actual runtime. Record which data is read, written or transferred and the lifetime of each input/result. Choose immutable snapshots, ownership transfer, messages or a justified synchronization method; a single specialist owning the code is not a thread-safety guarantee.

Specify engine/API thread affinity and where results become visible to the authoritative game state. Include ordering, synchronization/lock ordering if used, cancellation, shutdown/join and late-result disposal. Avoid waiting on a worker while holding a resource that worker needs. Name who invalidates results when the source state/session changes.

State equivalence requirements with the sequential behavior, including allowed numeric tolerance and ordering differences. Preserve deterministic RNG consumption or replay behavior only where the game contract requires it. Do not silently relax gameplay correctness to obtain speed.

Hand test design the relevant competing schedules: overlapping updates, cancellation before/after completion, shutdown with work pending and repeated execution. Select race detection or stress tools supported by the target; repeated success alone is not proof that races are absent.

Hand profiling a matched sequential baseline and target workload. Measure scheduling, data-copy/transfer, synchronization, memory and main-thread costs as well as worker time; include small workloads where parallel overhead can dominate. The implementation owner writes the change, test infrastructure supplies missing tools, and verification reports observed results and limits.
