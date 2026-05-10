---
description: Begin a new play session. Usage /session-start [optional-focus]
---

Begin a new play session.

1. Determine the next session number by counting existing files matching `sessions/play/*/*/session-*.md` (numeric suffix). The new number is one greater than the maximum, or 001 if none exist.

2. Compute the session log path: `sessions/play/YYYY/MM/session-NNN.md` using today's date and the new session number. Create the parent directory if needed.

3. Initialize the session log with this header:
   ```
   # Session NNN — YYYY-MM-DD
   
   **Focus:** $ARGUMENTS
   
   **Party state at session start:**
   <summarize from party/primary/*.md HP and conditions>
   
   ---
   
   ## Log
   ```

4. Read `meta/campaign-config.md` for system, tone, and starting context.

5. Read the primary PC sheet from `party/primary/`.

6. Invoke the world-state subagent with: "Has anything changed offscreen since last session?" (Phase 1 will return a minimal answer.)

7. Invoke the world-state subagent again to find the home-base scene context: "What is the current scene at home-base?" — or read `world/home-base/scene.md` and `world/home-base/overview.md` directly (these are not in dm/).

8. Greet the user with a session-start brief: where the party is, what's currently pressing, what's optionally available. Then narrate the opening of the scene and ask the player what they do.
