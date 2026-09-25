# Conversation and artifact language

## Settings and resolution
The project profile owns communication.preferredLanguage (user-facing communication and default artifact language) and optional communication.artifactLanguage (human-readable artifacts only). Use a BCP 47 tag such as ko, ko-KR, en or en-US, preserving the user's actual requested specificity. Record source and confirmed/inferred/conflicting status. Do not infer document language from the game's supported locales or engine.

For each output, resolve explicit user instruction for that output first, then artifactLanguage, then preferredLanguage, then the workflow default ko (Korean). Conversation uses an explicit conversation-language instruction, then preferredLanguage, then ko. If no setting exists, use Korean and record workflow-default as the source; do not infer another preference from the language of a message or ask a language questionnaire. A clearly intended temporary override affects only that output/run, not the saved profile. Save durable preferences only when the request authorizes a profile update. Preserve existing settings during unrelated profile edits.

Read relevant project instructions when resolving conflicts. Record the resolved language and source once in the run or artifact envelope and pass it to workers; direct skill invocation resolves it from the same profile. A material unresolved conflict is handled under current user authority, not by silently overwriting the profile.

## What follows the language
Write human-readable specifications, profile descriptions, plans, decisions, task instructions, handoff prose, review findings, test explanations and final reports in the resolved language. Translate template headings and descriptive table labels too. Shared English source templates are structures, not instructions to produce English documents. Small embedded records follow the same rule. Optional source titles and technical terms may retain their original names with an explanation when helpful.

Keep API names, code identifiers, file paths, skill/task/requirement IDs, schema property names, enumerated machine values, commands and hashes exact. In JSON/YAML preserve keys and contract-controlled values; localize only human-readable string content. Do not translate raw logs, stack traces, original quotations or original evidence files; explain them in the selected language and label any translation. Do not rename existing artifacts or translate shipped game strings merely to change workflow document language. Game locales remain a separate product setting.

Existing UI skills receive this preference through their task/handoff context. Preserve their schema keys, coverage IDs, fingerprints and approval records. Do not add unknown keys to an approved UI JSON profile or rewrite it just to carry document language; put the setting in the workflow profile and resolved handoff envelope.

## Handoff and verification
Before handing off, check that headings and human prose match the resolved language, inherited context is accessible to the consumer, and technical identifiers/evidence remain unchanged. A reviewer reports mismatched prose to its author. This check is separate from semantic/product correctness.

If a preference changes, use it for new or explicitly requested revised artifacts. Do not retroactively translate historical evidence or rewrite prior approvals. For a translated artifact, preserve requirement IDs and meaning, create a revision, and review any ambiguous terminology with the consumer. Text-language change alone does not require rerunning product execution tests; semantic or contract changes follow normal impact rules.

Examples: preferredLanguage=ko with no artifact override produces Korean prose even when templates are English. preferredLanguage=ko and artifactLanguage=en produces Korean conversation and English documents. An explicit request for one Japanese report overrides those defaults only for that report. In all cases an enum value such as completed or a function name score_removed stays exact.
