---
description: Begin a new play session. Usage /session-start [optional-focus]
---

Begin a new play session.

1. List existing session files matching `sessions/play/*/*/session-*.md`. Determine the next session number as one greater than the maximum existing numeric suffix (or 001 if none exist). Also note the path of the highest-numbered existing file — that is the prior session log, used in step 6.

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

6. The prior session log path is the one identified in step 1 as the highest-numbered existing file. If this is session 001 (no prior file existed in step 1's listing), the prior path is the empty string.

7. Invoke the world-state subagent with the structured query:

   > "Run offscreen developments tick. Prior session log: `<prior-path-or-empty>`. Active session log: `<active-path>`."

   where `<prior-path-or-empty>` is the path from step 6 (or empty string for session 001) and `<active-path>` is the active session log path from step 2.

   World-state will return a list of `(faction-name-or-null, surface-text)` pairs and any clock-filled beats. It also writes one summary line to the active session log per its protocol.

8. Invoke the world-state subagent again to find the home-base scene context: "What is the current scene at home-base?" — or read `world/home-base/scene.md` and `world/home-base/overview.md` directly (these are not in dm/).

9. Greet the user with a session-start brief: where the party is, what's currently pressing, what's optionally available. Then narrate the opening of the scene and ask the player what they do.

   Weave any non-null surface text from the offscreen tick into the opening narration as setting and atmosphere. Name a faction only if world-state's response named it (i.e., `faction-name` was non-null). Beats are integrated as concrete setting events ("a stagecoach driver was found dead this morning at the crossroads"), not abstract announcements.
