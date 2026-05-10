---
description: Ask the Mythic oracle a yes/no question. Usage /ask-oracle <question> [likelihood]
---

Invoke the mythic subagent to resolve this question.

Arguments: $ARGUMENTS

Parse the arguments as:
- The question itself is everything except the trailing likelihood word, if present.
- Recognized likelihoods: `impossible`, `nearly_impossible`, `very_unlikely`, `unlikely`, `50_50`, `likely`, `very_likely`, `nearly_certain`, `certain`. Default `50_50` if none specified.

Invoke the mythic subagent with:
- the question (for logging)
- the likelihood
- session log path: the active session log file in `sessions/play/`

Present the result to the user including: outcome (Yes/No, exceptional or not), the d100 roll, and any random event details.
