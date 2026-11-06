---
tags: [skill-creator]
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

Hand this task from OpenCode to my custom harness, AcmeAgent. It accepts pasted
prompts but I don't know its CLI flags. We're writing a CSV importer; no changes
have been made yet. Prepare the handoff in the current directory context, but
don't install anything, execute a model, or guess AcmeAgent's CLI syntax.
