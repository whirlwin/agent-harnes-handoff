# agent-harness-handoff

<p align="center">
  <img src="assets/logo.png" width="360" alt="Two robot coding agents awkwardly passing a context scroll while their cables get tangled.">
  <br>
  <em>Passing the context. Not the confusion.</em>
</p>

Move a task between coding-agent harnesses with a reviewable Markdown brief.
Claude Code → OpenCode, OpenCode → Claude Code, or a manual transfer to any
other harness that accepts a prompt. Repository name: `agent-harnes-handoff`.

This transfers context, **not** a native session database. Uncommitted changes
stay in the same working directory; no commits, pushes, transcript scraping,
credential copying, or permission bypasses happen automatically.

## Claude Code

Load the plugin for a session:

```bash
claude --plugin-dir /absolute/path/to/agent-harnes-handoff
```

Then ask “Hand this task off to OpenCode”, or invoke:

```text
/agent-harness-handoff:agent-harness-handoff opencode
```

## OpenCode V2

Expose the bundled skill through OpenCode's skill sources. Merge this into
your existing `opencode.jsonc`, preserving other settings:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "skills": ["/absolute/path/to/agent-harnes-handoff/skills"]
}
```

Then ask “Hand this task off to Claude Code”, or mention
`@agent-harness-handoff`. This is a portable skill plugin, not an OpenCode
server-plugin API extension. Other Agent Skills-compatible harnesses can load
`skills/agent-harness-handoff` using their own skill discovery mechanism.

## Standalone helper

Requires Bash 3.2+ and standard Unix utilities; Git is optional. The agent
writes the conversation summary; the helper adds a minimal working-tree snapshot.

```bash
helper=/absolute/path/to/agent-harnes-handoff/skills/agent-harness-handoff/scripts/handoff.sh
bundle=$(bash "$helper" prepare claude-code opencode "$PWD" <<'BRIEF'
## Goal
Finish the pagination fix without changing the API contract.
## Completed work
Updated the parser; existing user changes must be preserved.
## Verification
Unit tests pass. Integration tests have not run.
## Next steps
Read repository instructions, inspect the diff, then run integration tests.
BRIEF
)
cat "$bundle/HANDOFF.md"
bash "$helper" launch "$bundle" opencode       # Preview only
bash "$helper" launch "$bundle" claude-code    # Reverse direction
bash "$helper" launch "$bundle" another-agent  # Manual bootstrap prompt
```

Run the generated command in a **Bash-compatible terminal** to open the new
interactive session. Alternatively, after reviewing and approving the transfer,
run `bash "$helper" launch "$bundle" opencode --execute` from a terminal.
The helper never starts another model by default. Destination CLIs must already
be installed and authenticated. Their normal permission prompts still apply.

## Privacy and limitations

- Review the brief and captured filenames before transferring to another provider.
  The helper does not automatically detect or redact secrets.
- Bundles are created with private directory/file permissions in `$TMPDIR`
  (fallback `/tmp`), or an existing parent supplied as `prepare`'s final argument.
  They persist until you remove them. Nothing is uploaded by the helper itself.
- Launch previews contain the brief as a quoted argument. Avoid saving sensitive
  previews in shell history or logs. CLI arguments may also be visible to local
  process inspection; use a reviewed manual file handoff when that is unsuitable.
- Built-in launchers assume the same machine and original working directory.
  Remote transfers need separate repository and uncommitted-file transport.
- Stop source-side edits before the destination starts. Running jobs, tools,
  approvals, authentication, and hidden reasoning are not migrated.
- Unsupported targets use a manual prompt rather than guessed CLI flags.
- Paths and metadata arguments containing newlines are unsupported.

## Development

```bash
bash tests/handoff.sh
claude plugin validate . --strict
```

The tests use temporary repositories and mock CLI executables; no model calls
or live handoffs are made.

Three optional skill evaluations cover Claude Code → OpenCode, an unsupported
target, and sensitive context with a running job. They live under the skill's
`evals/` directory. Running them with `claude plugin eval` makes billed model
calls; they are not part of the shell test suite.
