---
name: game-build-packaging
description: Produce and inspect a local game build candidate from the project's build contract; excludes store submission, deployment and release approval.
---

## Inputs and owned output
Require the source candidate, target platform, toolchain/version, build command, content selection and output location. Own local build configuration changes within scope and the resulting package manifest. Reuse project commands instead of inventing an engine-specific pipeline.

## Execute
Identify the exact source/configuration used, including relevant uncommitted changes; a commit ID alone does not identify a dirty candidate. Check required tools and inputs before invoking the build. Keep local outputs separate from existing artifacts and user data.

Use the requested development/release configuration and asset selection. Keep signing credentials and secrets outside artifacts/logs. Stop the affected signing step when credentials or authorization are absent; an unsigned candidate must be labeled accordingly.

Run the build and preserve failure output. Inspect the produced file type, version, content/configuration and checksums. Check for unintentionally included debug controls or development endpoints when the target is a release candidate.

Perform the available launch/install smoke check only in the authorized local/test environment. A successful build is not runtime, store-policy or gameplay acceptance. If runtime access is missing, report packaging success with launch unverified.

## Handoff
Deliver artifact paths/hashes, source and toolchain identity, exact command, configuration, checks and remaining limitations. Return source failures to their implementer and acceptance to the project's release owner or an available readiness skill. Do not upload, submit, deploy, overwrite a public build or tag a release implicitly.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
For implementation and final delivery, apply [the delivery contract](../game-task-planning/references/delivery-contract.md).
