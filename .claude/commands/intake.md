---
description: Ingest source material into the campaign library. Usage: /intake <path>
---

The user wants to ingest source material at `$1`.

Invoke the librarian subagent with: "Ingest module material at `$1`. Active session log: null."

Surface the librarian's intake summary verbatim to the user. Then remind them of the NEXT STEPS the summary describes:

1. Review the staged files via `git status` and `git diff`.
2. Inspect any ambiguous classifications and adjust misclassified files in place.
3. Spot-check `dm/modules/<slug>/secrets.md` does NOT contain content also in `library/modules/<slug>/`.
4. Commit when satisfied. Do NOT run `/session-start` until the intake is committed.

Do NOT commit or push anything yourself. The user reviews and commits manually.
