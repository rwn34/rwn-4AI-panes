# CodeGraph + KiroGraph adoption plan

**Status:** DRAFT for review (Kiro + Claude + user; Kimi input still pending)
**Author:** claude-code (per handoff to-claude/202604211025)
**Date:** 2026-04-21

## Executive summary

Both tools solve the same problem — tree-sitter AST → SQLite knowledge graph → MCP tools — branded for different CLIs. CodeGraph is mature (516★, on npm, benchmark-backed). KiroGraph is early (44★, source-only, TypeScript). Adoption is **technically compatible** with the framework's safety layer. The main architectural question is timing: **parallel adoption** (Kiro's position) vs **phased** (my position).

## Decisions on Kiro's 9 points

### 1. ADR-0001 amendment

**Decision:** Expand Category E ("AI framework") to include both dirs. Don't create a new category — they're framework-adjacent dotfolders, same as `.ai/`, `.claude/`, `.archive/`.

```markdown
### E. AI framework

- ...existing entries...
- `.codegraph/` — CodeGraph local knowledge graph (Claude-only tool, 3rd party)
- `.kirograph/` — KiroGraph local knowledge graph (Kiro-only tool, 3rd party)
```

Cross-reference from both lines to this adoption plan (this file) for context. Rationale: readers should know which CLI owns each.

### 2. `.gitignore` updates

**Decision:** gitignore everything inside the tool dirs EXCEPT the human-authored config file. That way index/DB/snapshots regenerate per-machine but shared settings stay in git.

```gitignore
# CodeGraph — local knowledge graph (Claude)
.codegraph/*
!.codegraph/config.json

# KiroGraph — local knowledge graph (Kiro)
.kirograph/*
!.kirograph/config.json
```

If the tools support per-project shared settings via `config.json`, this gives contributors a consistent indexing baseline without bloating history with DBs (which can hit 100+ MB on large codebases).

If `config.json` isn't meaningful to share (e.g., contains absolute paths), gitignore the whole dir. Flag to verify during Phase 0 of install.

### 3. CodeGraph MCP config placement

**Decision:** project-local `.mcp.json` if CodeGraph supports it; global `~/.claude.json` as fallback.

**Why local is preferred:** fits the framework's "everything a project needs is in the project" principle. Global config creates invisible per-machine state that breaks when cloning to a new dev's machine.

**Action:** during install, verify CodeGraph's MCP server supports project-local config by checking its docs or testing with an `.mcp.json` at project root. If it works, commit `.mcp.json` to git (already permitted by ADR-0001 Category E). If only global works, document in README that each contributor must run `npx @colbymchenry/codegraph install` on their machine.

### 4. KiroGraph hook coexistence

**Decision:** coexist fine. Different event types from ours.

| Source | Events used | Purpose |
|---|---|---|
| Our safety hooks | `preToolUse` × 4 matchers | Block unsafe writes/commands before they happen |
| KiroGraph | `fileEdited`, `fileCreated`, `fileDeleted`, `agentStop` | Sync knowledge graph after changes land |

No event collision. The Kiro runtime fires both sets.

**⚠ Known caveat:** Kiro's subagent hook-inheritance bug (upstream issue #7671) affects KiroGraph too. When a Kiro subagent edits files, the `fileEdited` hook doesn't fire — index goes stale silently. Document in `.ai/known-limitations.md`. Mitigation: run `kirograph sync` manually or accept staleness until upstream fix.

### 5. Write boundary implications

**Decision:** add to each CLI's `deniedPaths` the OTHER CLI's graph dir. Kimi gets both in denied.

| CLI | Can write to | Cannot write to |
|---|---|---|
| Claude | `.codegraph/**` (via CodeGraph MCP server process) | `.kirograph/**` |
| Kiro | `.kirograph/**` (via KiroGraph runtime hooks) | `.codegraph/**` |
| Kimi | neither | `.codegraph/**`, `.kirograph/**` |

Update `.claude/hooks/pretool-write-edit.sh` Rule 1 section to add `.kirograph/**` as blocked for Claude. Same pattern for Kimi's + Kiro's equivalents.

Root-file guard: the dirs have `/` in the path so they pass root-file rules automatically. No change needed there.

### 6. Framework test suite updates

**Decision:** add one test per CLI per dir — verify cross-CLI writes are blocked, same-CLI writes are allowed.

Claude test_hooks.sh additions:
```
t+1: write to .codegraph/foo.db → allow (Claude's own tool)
t+2: write to .kirograph/foo.db → block (not Claude's territory)
```

Kimi test_hooks.sh additions:
```
t+1: write to .codegraph/foo.db → block
t+2: write to .kirograph/foo.db → block
```

Kiro test_hooks.sh additions:
```
t+1: write to .kirograph/foo.db → allow
t+2: write to .codegraph/foo.db → block
```

Total: +6 tests across the 3 suites. Bumps CI coverage correspondingly. SSOT drift-check unaffected (these are tool configs, not SSOT replicas).

### 7. Kimi CLI — asymmetry handling

**Decision:** document asymmetry; defer Kimi integration until real-project pain emerges.

Options evaluated:
- **(A)** Extend CodeGraph to Kimi via generic MCP. Requires verifying Kimi's MCP support speaks CodeGraph's schema. Possible per Kimi docs (supports 13 hook events + MCP).
- **(B)** Find a Kimi-native code-graph tool. None known.
- **(C)** Do nothing; Kimi works without graph, relies on its high-budget raw context.

**Recommendation:** start with (C). Test Kimi's large-project performance first with no graph. If tool-call volume becomes prohibitive, try (A) with CodeGraph's MCP server shared across Claude + Kimi (one graph, two clients). Avoids 3rd graph install.

### 8. Install sequence

**Point of divergence from Kiro.**

**Kiro's position:** parallel install, both CLIs do their own tool independently.

**My position:** phased, CodeGraph first.

Reasons for phased:
- Two new dependencies at once = coupled failure modes, hard to diagnose.
- CodeGraph is mature; KiroGraph is experimental. Different risk profiles shouldn't mix.
- Kiro's existing runtime bug (subagent hook inheritance) means KiroGraph has a known dirty interaction path on day 1.
- Phased approach lets you verify the 92-94% tool-call reduction claim on CodeGraph before committing to the same architecture for Kiro.

Proposed phased sequence:

**Phase A — ADR + framework housekeeping (low-risk, decide without adoption):**
1. Claude amends ADR-0001 per point 1 above
2. Claude updates `.gitignore` per point 2
3. Claude dispatches handoffs to Kimi + Kiro for their parts of point 5 (deniedPaths) + point 6 (tests)
4. All 3 CLIs commit their parts
5. Verify test suites green across CIs

**Phase B — CodeGraph adoption (Claude only):**
6. Claude runs `npx @colbymchenry/codegraph` on a real or representative project
7. Claude commits initial `.codegraph/config.json` (if shared-worthy)
8. Claude measures: tool-call count before/after on equivalent exploration tasks
9. Report results. If measurement confirms ≥50% tool-call reduction → proceed. If <50% → reassess before Phase C.

**Phase C — KiroGraph adoption (Kiro only, after Phase B success):**
10. Kiro runs `kirograph install`
11. Kiro commits initial `.kirograph/config.json`
12. Kiro documents staleness risk per point 4 caveat

**Phase D — Kimi integration (only if Phase B shows clear wins):**
13. Test whether Kimi can connect to CodeGraph's MCP server as a second client
14. If yes, Kimi shares Claude's graph. If no, document Kimi-graph-gap in known-limitations.

**If parallel (Kiro's position) is chosen over phased, collapse Phases B+C to single step, understanding the risk.**

### 9. Semantic embeddings decision

**Decision:** start structural-only for both tools. Enable embeddings later if search quality becomes a bottleneck.

Rationale:
- Embeddings add 130MB+ model download per CLI per machine
- Structural indexing alone is what delivers the "92-94% tool-call reduction" benchmark
- Embeddings improve semantic search ("find functions similar to X") but not call-graph traversal (where most token savings come from)
- Easier to turn ON than turn OFF once model is downloaded and cached

Document in respective `config.json` files + README that embeddings are available as opt-in.

## Risks / blockers identified

1. **Kiro subagent hook inheritance (upstream #7671)** — affects KiroGraph's auto-sync for subagent writes. Documented limitation, not a blocker but a known-limitations entry.
2. **CodeGraph MCP config global-only** — if true, undermines project-local principle. Phase A step 3 verifies.
3. **Tool-call reduction claim on YOUR codebase** — 92-94% benchmark may not generalize. Phase B step 8 verifies.
4. **Two 3rd-party dependencies** — both MIT-licensed, both local, but still external surface area. If either tool breaks in a future release, framework adoption is dependent on their maintenance.
5. **Kimi asymmetry** — if (C) + (A) both fail, Kimi permanently lacks code-graph capability; framework's "3-CLI parity" narrative weakens.
6. **Index staleness** — silent failure mode. Auto-sync hooks are a happy path; when they don't fire (subagent runtime bug, offline, file-watcher limits), AI gets wrong answers from stale graph.

## Divergence summary

The plan follows Kiro's structure except at point 8:

| Decision | Kiro | Claude |
|---|---|---|
| Parallel install | ✓ | ✗ — phased CodeGraph first |
| Both tools worth adopting | ✓ | ✓ (conditionally, after CodeGraph success) |
| Structural-only start | ✓ | ✓ |
| Each CLI owns its own tool | ✓ | ✓ |
| ADR amendment | ✓ | ✓ |

User decides on phasing. Once settled, execution handoffs get dispatched.

## Next steps (pending approval)

1. User reviews this plan + Kimi's opinion (when available)
2. User picks phased or parallel
3. Claude amends ADR-0001 + `.gitignore` (Phase A steps 1-2)
4. Claude dispatches handoffs for the cross-CLI parts (Phase A steps 3-4)
5. Execution begins per chosen sequence

## Open questions (for user to answer before execution)

- [ ] Phased or parallel?
- [ ] Commit `config.json` files to git, or gitignore whole dirs?
- [ ] CodeGraph global `~/.claude.json` acceptable if project-local doesn't work?
- [ ] Include embedding model download in initial adoption, or strictly structural-only?
- [ ] Kimi approach: do nothing (C), extend CodeGraph via MCP bridge (A), or find an alternative?
- [ ] Acceptance criteria for "Phase B success" before unblocking Phase C? (My proposal: ≥50% tool-call reduction on an equivalent task)
