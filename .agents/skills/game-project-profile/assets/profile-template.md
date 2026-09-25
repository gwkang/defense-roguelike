# Project profile

Revision: <revision>. Keep only applicable rows, translate prose into the artifact language, and retain machine keys. Values are current unless marked unknown, conflicting or proposed.

| Setting | Value | Source |
| --- | --- | --- |
| Engine/version; 2D/3D | | |
| Platform | | |
| Display/input | Value or exact existing settings reference | |
| Game locale | | |
| communication.preferredLanguage | ko unless explicitly overridden | User preference or workflow default |
| communication.artifactLanguage | Omit unless different from preferredLanguage | |
| workflowRunRegistryPath | Exact project-relative path when stateful workflow reuse is supported | |
| modelRoutingProfilePath | Exact project-relative mapping when capability-tier model routing is supported | |

## Optional knowledge settings

When enabled, record `knowledge.enabled`, stable `knowledge.projectName`, `knowledge.root` (`<project-name>-wiki/`), `knowledge.indexPath` and `knowledge.policyPath`. Keep exact project-relative locators here; source authority, write policy and checks stay in the referenced project policy. Omit this section for projects without integration. Follow the [knowledge contract](../../game-task-planning/references/knowledge-contract.md); do not migrate an existing wiki while collecting settings.

## Commands

Working directory: <path>. State whether definitions were inspected or execution tested; keep logs elsewhere.

| Purpose | Command |
| --- | --- |
| Run / build / relevant checks | | |

## References

Link existing product criteria, UI settings and workflow policy as needed. Do not copy their rules. Add only unresolved settings that affect upcoming work; omit this section if there are none. Keep source hashes, reviewer identity and detailed results in the existing handoff, not this settings table.
