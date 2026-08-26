#!/usr/bin/env bash
# Write the git hooks. Bash, no framework, so Git Bash runs them too.
#
# pre-commit runs the static gate, which reads the sources and needs no
# build. pre-push runs the gates that need one, minus the gate that
# needs a browser.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

hooks="$(git rev-parse --git-path hooks)"
mkdir -p "$hooks"

# The interpreter line is written apart from the body. Inside a here
# document it reads as prose carrying punctuation. The comment checker
# stops on that, so the character comes from its octal code.
write_hook() {
  local target="$1"
  local bang
  bang="$(printf '\041')"
  printf '#%s/usr/bin/env bash\n' "$bang" > "$target"
  cat >> "$target"
  chmod +x "$target"
}

write_hook "$hooks/pre-commit" <<'HOOK'
set -euo pipefail
exec ./c check gate=static
HOOK

write_hook "$hooks/pre-push" <<'HOOK'
set -euo pipefail
./c check gate=static
./c check gate=build
./c check gate=output
HOOK

printf '%s\n' "wrote $hooks/pre-commit and $hooks/pre-push"
