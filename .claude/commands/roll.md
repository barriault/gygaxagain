---
description: Roll dice via the dice subagent. Usage /roll <expression-or-skill> [character] [reason]
---

Invoke the dice subagent to resolve this roll.

Arguments: $ARGUMENTS

Parse the arguments as:
- If first arg looks like a dice expression (matches `\d+d\d+` or pure integer math), pass it as a raw expression.
- Otherwise treat the first arg as a skill name; the second arg (if present) is the character; remaining args after `--` or in quotes are the reason.

Invoke the dice subagent with:
- expression or (skill, character)
- reason (if provided)
- session log path: `sessions/play/YYYY/MM/session-NNN.md` (use the active session log file — find the most recently modified file in `sessions/play/`)

Report the result to the user as plain prose, including the breakdown.
