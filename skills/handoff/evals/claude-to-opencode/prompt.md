---
tags: [skill-creator]
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

Prepare a handoff from this Claude Code session to OpenCode, but don't launch it.
We are fixing pagination. The parser is updated, unit tests pass, integration
tests have not run, and I have unrelated local edits you must preserve. Next
step is to inspect the parser diff and run integration tests. Use the current
directory and include those facts in the brief. Don't call a model.
