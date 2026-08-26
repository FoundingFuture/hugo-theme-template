#!/usr/bin/env bash
# Windows rules. Git Bash runs these scripts as written, or it does not
# run them at all. The difference stays invisible on Linux until
# somebody reports it.
#
# The rules are data, in portable-rules.txt. That file carries no
# comment of its own, because a pattern written beside its own
# explanation would match the explanation. Each line is a grep pattern,
# a bar, then the message to print.
# reads: c tools/scripts tools/conformance/scripts .github/workflows .gitattributes
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

RULES=tools/scripts/check/portable-rules.txt
status=0
report() { printf '%s\n' "$1"; status=1; }

while IFS= read -r link; do
  [ -n "$link" ] && report "$link:1: symlink. A Windows checkout mishandles one."
done < <(git ls-files -s 2>/dev/null | awk '$1 == "120000" {print $4}')

if [ ! -f .gitattributes ]; then
  report ".gitattributes:1: missing. Line endings will drift on a Windows checkout."
elif ! grep -q 'text=auto eol=lf' .gitattributes; then
  report ".gitattributes:1: no '* text=auto eol=lf'. Line endings will drift."
fi

[ -f "$RULES" ] || { echo "$RULES:1: missing."; exit 1; }

# The python and the workflow shell steps run on the same machines as
# the shell scripts. They follow the same rules.
files=""
for file in c tools/scripts/*.sh tools/scripts/check/*.sh tools/conformance/scripts/*.sh \
            tools/scripts/*.py tools/scripts/check/*.py tools/conformance/scripts/*.py \
            .github/workflows/*.yml; do
  [ -f "$file" ] && files="$files $file"
done

while IFS= read -r rule; do
  case "$rule" in ""|\#*) continue ;; esac  # docs-style:ignore
  pattern="${rule%%|*}"
  message="${rule#*|}"
  for file in $files; do
    while IFS=: read -r line _; do
      [ -n "$line" ] && report "$file:$line: $message"
    done < <(grep -n -e "$pattern" "$file" 2>/dev/null)
  done
done < "$RULES"

exit $status
