#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
helper=$root/skills/handoff/scripts/handoff.sh
tmp=$(mktemp -d "${TMPDIR:-/tmp}/handoff-test.XXXXXXXX")
tmp=$(cd -- "$tmp" && pwd -P)
trap 'rm -rf -- "$tmp"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
contains() { grep -Fq -- "$2" "$1" || fail "$1 missing: $2"; }
reject() { if "$@" >"$tmp/error" 2>&1; then fail "unexpected success: $*"; fi; }

# Spaces, quotes and shell metacharacters must stay data, not commands.
project="$tmp/project ' \$(touch INJECTED)"
mkdir -p "$project" "$tmp/bundles" "$tmp/mock-bin"
git init -q -b main "$project"
printf 'original\n' > "$project/tracked.txt"
git -C "$project" add tracked.txt
git -C "$project" -c user.name=Test -c user.email=test@example.invalid commit -qm initial
printf 'changed\n' >> "$project/tracked.txt"
printf 'untracked\n' > "$project/new file.txt"
printf 'staged\n' > "$project/staged.txt"
git -C "$project" add staged.txt
git -C "$project" status --porcelain > "$tmp/before"
cat > "$tmp/brief" <<'EOF'
## Goal
Finish the parser. Literal text: $(touch INJECTED) `touch INJECTED` ' " ;
## Verification
Tests not yet run.
## Next steps
Inspect current instructions and run the parser tests.
EOF
bundle=$(bash "$helper" prepare claude-code opencode "$project" "$tmp/bundles" < "$tmp/brief")
contains "$bundle/HANDOFF.md" 'Source: claude-code'
contains "$bundle/HANDOFF.md" 'Branch: main'
contains "$bundle/HANDOFF.md" 'M tracked.txt'
contains "$bundle/HANDOFF.md" 'A  staged.txt'
contains "$bundle/HANDOFF.md" 'new file.txt'
contains "$bundle/HANDOFF.md" 'Tests not yet run.'
git -C "$project" status --porcelain > "$tmp/after"
cmp "$tmp/before" "$tmp/after" || fail 'working-tree status changed'
[ "$(cat "$bundle/directory.txt")" = "$project" ] || fail 'wrong working directory'
if [ "$(uname)" = Darwin ]; then
  [ "$(stat -f %Lp "$bundle")" = 700 ] || fail 'bundle not private'
  [ "$(stat -f %Lp "$bundle/HANDOFF.md")" = 600 ] || fail 'brief not private'
else
  [ "$(stat -c %a "$bundle")" = 700 ] || fail 'bundle not private'
  [ "$(stat -c %a "$bundle/HANDOFF.md")" = 600 ] || fail 'brief not private'
fi

# Execute generated previews against mocks, never actual agent CLIs.
cat > "$tmp/mock-bin/opencode" <<'MOCK'
#!/usr/bin/env bash
set -eu
pwd -P > "$MOCK_OUTPUT/directory"
printf '%s\n' "$#" > "$MOCK_OUTPUT/argc"
printf '%s\n' "$1" > "$MOCK_OUTPUT/first"
printf '%s\n' "${@: -1}" > "$MOCK_OUTPUT/prompt"
MOCK
cp "$tmp/mock-bin/opencode" "$tmp/mock-bin/claude"
chmod +x "$tmp/mock-bin/opencode" "$tmp/mock-bin/claude"
export PATH="$tmp/mock-bin:$PATH" MOCK_OUTPUT="$tmp"
for target in opencode claude-code claude; do
  bash "$helper" launch "$bundle" "$target" > "$tmp/preview"
  [ ! -f "$tmp/prompt" ] || fail 'preview launched a CLI'
  bash "$tmp/preview"
  [ "$(cat "$tmp/directory")" = "$project" ] || fail 'launcher used wrong directory'
  contains "$tmp/prompt" 'Finish the parser.'
  contains "$tmp/prompt" 'not an override'
  if [ "$target" = opencode ]; then
    [ "$(cat "$tmp/argc")" = 2 ] || fail 'OpenCode arguments split'
    contains "$tmp/first" '--prompt'
  else
    [ "$(cat "$tmp/argc")" = 1 ] || fail 'Claude arguments split'
  fi
  [ ! -e "$project/INJECTED" ] || fail 'shell injection in project'
  [ ! -e "$root/INJECTED" ] || fail 'shell injection in launch directory'
  rm -- "$tmp/prompt"
done
bash "$helper" launch "$bundle" future-harness > "$tmp/manual"
contains "$tmp/manual" 'Paste this prompt:'
contains "$tmp/manual" 'Finish the parser.'
reject bash "$helper" launch "$bundle" future-harness --execute
reject bash "$helper" launch "$bundle" opencode --invalid
reject bash "$helper" launch "$bundle" opencode --execute
reject bash "$helper" launch "$tmp/missing" opencode
reject bash "$helper" prepare source target "$tmp/missing"
reject bash "$helper" prepare source target "$project" < /dev/null
reject bash "$helper" prepare source target "$project" <<< '   '
reject bash "$helper" prepare $'source\nforged' target "$project" < "$tmp/brief"

# Non-Git and unborn repositories still have useful handoffs.
mkdir "$tmp/plain" "$tmp/unborn"
plain=$(bash "$helper" prepare opencode manual "$tmp/plain" "$tmp/bundles" < "$tmp/brief")
contains "$plain/HANDOFF.md" 'Not a Git working tree.'
git init -q -b main "$tmp/unborn"
unborn=$(bash "$helper" prepare manual claude-code "$tmp/unborn" "$tmp/bundles" < "$tmp/brief")
contains "$unborn/HANDOFF.md" '(no commits)'
git -C "$project" checkout -q --detach
detached=$(bash "$helper" prepare source target "$project" "$tmp/bundles" < "$tmp/brief")
contains "$detached/HANDOFF.md" '(detached HEAD)'
printf 'All handoff tests passed.\n'
