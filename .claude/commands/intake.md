---
description: Ingest source material into the campaign library. Usage: /intake <path>
---

The user wants to ingest source material at `$1`.

Invoke the librarian subagent with: "Ingest module material at `$1`. Active session log: null."

Surface the librarian's intake summary verbatim to the user. Then remind them of the NEXT STEPS the summary describes:

1. Review the staged files via your own shell/editor (the main agent cannot read `dm/`).
2. Inspect any secret-content notes the librarian flagged for verification.
3. Spot-check the `library/index.md` entry is genre-level only and does not leak module content.
4. Commit when satisfied. Do NOT run `/session-start` until the intake is committed.

Do NOT commit or push anything yourself. The user reviews and commits manually.
