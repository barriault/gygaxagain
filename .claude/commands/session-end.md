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

4. Run:
   ```
   git add -A
   git commit -m "session NNN: <one-line summary>"
   ```

5. Report success and the commit hash to the user.

Phase 1 does **not** run a bookkeeper verification phase — that lands in Phase 4. The working-tree-as-committed is trusted as the session record.
