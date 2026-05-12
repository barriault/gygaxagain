---
description: Close a play session. Commits all working-tree changes as one logical commit.
---

Close the active session.

1. Locate the active session log (most recently modified file in `sessions/play/`).

2. Append a session-end summary section:
   ```
   
   ---
   
   ## Session-end summary
   
   <2-4 sentences summarizing what happened, who was met, what's pending.>
   
   **Loose ends:**
   - <thread or open question>
   - <thread or open question>
   ```

3. Invoke the mythic subagent to adjust the chaos factor based on whether the player was in or out of control of the session arc. Default in Phase 1: leave unchanged. If asked for a recommendation, surface the question to the user.

4. Invoke the bookkeeper subagent with `"Audit session <path>."` where `<path>` is the active session log from step 1. The bookkeeper reads the log, runs three narrator-discipline checks (dice-line presence, oracle-call presence, primary-PC overreach), and appends a `## Bookkeeper audit` section to the log. The bookkeeper returns a brief summary; surface it to the user. Findings do not block the commit in this phase.

5. Run:
   ```
   git add -A
   git commit -m "session NNN: <one-line summary>"
   ```

6. Report success and the commit hash to the user.

Phase 4a runs a minimum-viable bookkeeper audit at session-end. Findings are surfaced and persisted in the session log under `## Bookkeeper audit` but do not block the commit. Subsequent Phase 4 sub-phases will extend the audit's reach (live-write integrity, subagent decision audits, structural-change proposals).
