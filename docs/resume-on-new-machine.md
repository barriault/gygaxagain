# Resume on a new machine — Claude Code session prompt

Paste the prompt below into a fresh Claude Code session on the new machine, in the cloned `gygaxagain` repo. The prompt orients Claude, walks through environment verification, and identifies what to do next.

If something fails during verification, stop and fix it before continuing — the engine's discipline boundaries depend on dm-fs MCP working correctly.

---

## The prompt

Copy from here to the end of the file:

---

I'm resuming work on the gygaxagain solo D&D campaign engine after switching to a different computer. Before we do anything else, I need you to verify the environment is fully set up and all prior phases are in working order. The repo's design specs and plans live under `docs/superpowers/specs/` and `docs/superpowers/plans/`.

## Current state (per project history)

- **Phase 1** (MVP session), **Phase 2a–2d** (factions, revelations, threads, Mythic-event spotlight), **Phase 3a–3e** (module + lore intake, runtime librarian queries, revelation + faction auto-proposals), **Phase 4a** (MVP bookkeeper), and **Phase 4b** (bookkeeper subagent-decision audits) are all merged to `main` and shipped.
- The next planned phase is **Phase 4c** — live-write integrity audit, intake-decision audit, library-bypass detection, structural-change proposals, ad-hoc bookkeeper invocation slash command (`/audit-session`), and re-audit mode flags. See `docs/superpowers/specs/2026-05-11-phase-4b-bookkeeper-subagent-audits-design.md` "Phase 4b → Phase 4c+ handoff" section and `CLAUDE.md` `## Current phase scope` for the full roadmap.
- **Outstanding issue:** Phase 4b's smoke test ran in a degraded session where the dm-fs MCP did not activate for the bookkeeper subagent despite syntactically correct `mcpServers: [dm-fs]` frontmatter. The smoke test validated checks 1-3 and the replace-on-rerun semantic, but checks 4-6 were skipped via the documented graceful-degradation path. Before starting Phase 4c, validate that the v2 bookkeeper can actually use dm-fs MCP in this environment by re-running the smoke test against session-005.

## Step 1 — Repo state check

Run these and report results:

```bash
pwd
git status
git log --oneline -10
git remote -v
```

Expected:
- `pwd` shows the new computer's path to the cloned `gygaxagain` repo.
- `git status` is clean (working tree).
- `git log --oneline -10` shows recent merge commits including `Merge phase-4b: bookkeeper subagent-decision audits` and `Merge phase-4a: MVP bookkeeper subagent` near the top.
- `git remote -v` shows an origin (so we can pull/push).

If commits are missing, `git pull origin main` (or whichever branch is the source of truth).

## Step 2 — Python venv + dm-fs MCP install

The dm-fs MCP is a Python package at `tools/dm-fs-mcp/`. It needs a Python venv with the package installed, accessible at a path the `.mcp.json` will reference.

Check if the venv exists at the repo root:

```bash
ls -la .venv/ 2>&1 | head -5
```

If `.venv/` doesn't exist, create it and install:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e tools/dm-fs-mcp
```

If `.venv/` exists, activate and verify the dm-fs MCP server is importable:

```bash
source .venv/bin/activate
python -c "import dm_fs; print('dm-fs importable')"
```

## Step 3 — Check `.mcp.json` paths

The repo's `.mcp.json` declares the dm-fs MCP server with absolute paths to the Python interpreter and the `DM_ROOT` directory. These paths are likely set for the old machine and need to be updated for the new one.

```bash
cat .mcp.json
```

Expected fields:
- `command`: should point at the new machine's `.venv/bin/python` (the absolute path will differ from `/Users/barriault/dnd/gygaxagain/.venv/bin/python`).
- `args`: `["-m", "dm_fs.server"]` (machine-independent — don't touch).
- `env.DM_ROOT`: should point at the new machine's `<repo>/dm` (the absolute path will differ from `/Users/barriault/dnd/gygaxagain/dm`).

If the paths are wrong for the new machine, fix them. Use `pwd` from Step 1 to construct the correct absolute paths. **Do not commit machine-specific paths if the repo is shared across machines** — these may need to be `.gitignore`d or use environment variables. For now, just make them correct for this machine and we'll deal with portability later.

## Step 4 — Run the dm-fs MCP test suite

```bash
cd tools/dm-fs-mcp && source ../../.venv/bin/activate && python -m pytest -q 2>&1 | tail -5
```

Expected: `37 passed`.

If tests fail: the dm-fs MCP install is broken. Investigate before proceeding.

## Step 5 — Verify Claude Code recognizes the dm-fs MCP

In this Claude Code session, run the `/mcp` slash command (you'll need to do this; I can't invoke it for you). It should list `dm-fs` as a registered server, ideally connected/approved.

If the server isn't listed:
- Confirm you're in the repo root (Claude Code reads `.mcp.json` from the project root).
- Try fully exiting and relaunching Claude Code so it re-reads `.mcp.json`.
- If still not recognized, check Claude Code's MCP documentation for any approval/activation step that may be required when a new MCP server is detected.

If the server is listed but not approved/connected, follow Claude Code's prompts to approve it.

## Step 6 — Smoke-test the bookkeeper end-to-end (validates Phase 4b's unvalidated paths)

This is the load-bearing verification step. Phase 4b's bookkeeper has six checks; checks 4-6 use dm-fs MCP. Phase 4b's original smoke test could not validate checks 4-6 because the MCP didn't activate in that session. Re-run the smoke test now:

```
Agent(subagent_type="bookkeeper", prompt="Audit session sessions/play/2026/05/session-005.md.")
```

The bookkeeper will:
- Detect the prior `## Bookkeeper audit` section (left over from the partial Phase 4b smoke test).
- Truncate it via the replace path.
- Run checks 1-3 (likely zero findings; session-005 keeps narrative prose in `## Session-end summary` which is excluded per contract).
- **Run checks 4-6 against `dm/factions/`, `dm/revelations/`, `dm/threads/` via dm-fs MCP.** This is what we need to validate.
- Append the new audit section.

**Expected outcome (success path):** the audit-complete summary line shows six counts (most likely a mix of zeros and small numbers of plausible-reasoning anomalies). The three new subsections (`### Faction tick rationale`, `### Clue delivery confirmation`, `### Thread state consistency`) contain real findings (or `- (none)`) rather than `(skipped — dm-fs MCP unavailable)`.

**If checks 4-6 are still skipped:** the dm-fs MCP environment issue persists. Diagnostic next steps:
- Check `tools/dm-fs-mcp/access.log` — were any bookkeeper-issued reads logged? (Expect entries with `list_dm_dir factions`, `read_dm_file revelations/r-NNN.md`, etc.)
- Compare the bookkeeper frontmatter to the librarian frontmatter — both have `mcpServers: [dm-fs]` and the librarian works. If they diverge in any way, that's a clue.
- Try dispatching the librarian (e.g., `Agent(subagent_type="librarian", prompt="consult-library for testing. Active session log: null.")`) — if it has dm-fs access and the bookkeeper doesn't, the issue is bookkeeper-specific.

**If checks 4-6 fire successfully:** commit the smoke-test artifact (the v2 audit with real subagent-decision findings replacing the partial-validation Phase 4b artifact):

```bash
git add sessions/play/2026/05/session-005.md
git commit -m "Phase 4b smoke test (post-resume): bookkeeper v2 full re-audit with dm-fs MCP active"
```

## Step 7 — Confirm narrator information-asymmetry boundaries

Quick check that the narrator-facing dm/ denies are intact (relative-path probes):

```bash
cd /Users/barriault/dnd/gygaxagain 2>/dev/null || cd "$(git rev-parse --show-toplevel)"
cat dm/factions/cult-of-myrkul.md 2>&1 | head -1
cat dm/modules/ancient-tomb-of-phandalin/secrets.md 2>&1 | head -1
cat library/lore/test-bestiary/entries/goblin.md 2>&1 | head -3
```

Expected:
- First two: denied by the Bash deny rules in `.claude/settings.json`.
- Third: file content displays (Phase 3c lore is narrator-readable).

If the dm/ probes succeed (not denied), the deny rules need to be reviewed — possibly the new machine's Claude Code is using a different settings cascade.

## Step 8 — Once verified, what's next

After all verification passes:

1. If Step 6 produced a real Phase 4b smoke-test artifact, that's a meaningful improvement on the Phase 4b state. Commit it (covered in Step 6).
2. We can begin **Phase 4c brainstorming**. Phase 4c expands the bookkeeper with live-write integrity audit, intake-decision audit, library-bypass detection, structural-change proposals, ad-hoc invocation slash command (`/audit-session <path>`), and re-audit mode flags. The Phase 4b → Phase 4c+ handoff section in the Phase 4b design spec lists the candidates.
3. The working style we've been using: brainstorm with the user (`superpowers:brainstorming`), present 2-3 slicing options with recommendation, design in three sections (scope/architecture/smoke test) with per-section approval, write spec, write plan (`superpowers:writing-plans`), execute via subagent-driven development (`superpowers:subagent-driven-development`). Auto-mode is the user's preference: minimize interruptions, prefer action over planning, make reasonable assumptions on routine decisions, expect course corrections.

When you've completed Steps 1-7 and everything checks out, tell me what passed, what (if anything) needed fixing, and whether the Phase 4b post-resume re-audit produced real findings for checks 4-6. Then we can decide whether to ship a follow-up Phase 4b commit (if the re-audit succeeded) or start brainstorming Phase 4c.
