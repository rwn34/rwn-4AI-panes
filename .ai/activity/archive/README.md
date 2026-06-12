# Activity Log Archive

Historical activity-log entries moved out of the live `.ai/activity/log.md` so the
live file stays small. **AI CLIs do not read files in this directory during routine
operations.** Only consulted when the user explicitly references historical activity
(e.g., "what did we decide in March?", "when did we first set up the hooks?").

## Layout

One file per calendar month:

    YYYY-MM.md

Inside each monthly archive, entries are **grouped by day** for readability at
scale:

    ## 2026-04-17
    ### 16:05 — claude-code
    - Action: ...
    - Files: ...
    - Decisions: ...

    ### 15:50 — kiro-cli
    - Action: ...
    ...

    ## 2026-04-16
    ...

Within a day block, newest entries on top (same as live log). Day blocks are in
reverse chronological order.

## Archival protocol

Manual. Triggers (any is fine):

- **Month rollover** — once a calendar month has fully closed, move that month's
  entries to `YYYY-MM.md`.
- **Size threshold** — if the live `log.md` exceeds ~500 lines, archive the oldest
  closed-month entries regardless of recency.
- **Explicit request** — user says "archive the log".

Steps:

1. Read `.ai/activity/log.md`.
2. Identify entries whose date falls in closed months (or whatever range you're archiving).
3. Cut those entries from the live log.
4. Regroup by day and append to `archive/YYYY-MM.md` (create if missing). Preserve
   newest-day-first ordering in the archive file.
5. Prepend a new entry to the live log noting what was archived and where.
6. Never delete entries — only move.

Because the three CLIs run in one project, any CLI can perform the archive. Archival
is a substantive action; log it in the live log like any other.

## Read rule for AI CLIs

Do NOT read `.ai/activity/archive/**` during routine work — not in the session-start
log scan, not in the `UserPromptSubmit` hook injection, not when scanning for recent
activity. The auto-injection hook only touches `.ai/activity/log.md`, so archive
files are skipped by default.

Only read archive files when the user explicitly references historical activity.

## Timestamp note

Timestamps inside archived entries are preserved verbatim — they are the local
wall-clock times at which the original CLIs prepended the entries, with the same
caveats (prepend order authoritative, timestamps are annotations).
