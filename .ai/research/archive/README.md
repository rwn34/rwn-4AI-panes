# Research Archive

Superseded or outdated research documents. **AI CLIs do not read files in this
directory during routine operations.** Only consulted when the user explicitly
references historical research (e.g., "what were the tradeoffs we weighed last
time?", "pull up the old orchestrator design").

## Layout

One file per archived research doc, with a date suffix:

    <original-name>-YYYY-MM-DD.md

The date is the **archival date** (when the doc was moved here), not its creation
date. If you archive the same doc multiple times (successive supersedings), each
version gets its own dated file.

Example: if `orchestrator-claude.md` is superseded on 2026-05-20, it becomes
`archive/orchestrator-claude-2026-05-20.md`.

## Archival protocol

Manual. Triggers:

- **Superseded** — a newer research doc replaces the decisions captured in this one.
- **Landed + obsolete** — the recommendations in the doc have been implemented and
  the doc no longer serves as an active reference.
- **Explicit request** — user says "archive this research".

Steps:

1. Pick the active research file in `.ai/research/<name>.md`.
2. Move it to `archive/<name>-YYYY-MM-DD.md` where the date is today.
3. Optionally prepend a one-line note at the top of the archived file explaining
   why it was archived (what superseded it, or what landed from its
   recommendations).
4. Log the archival in `.ai/activity/log.md`.

Never delete — only move.

## Read rule for AI CLIs

Do NOT read `.ai/research/archive/**` during routine work. Active research in
`.ai/research/*.md` is the default scope for CLIs looking up prior design context.

Only read archive files when the user explicitly references historical research.
