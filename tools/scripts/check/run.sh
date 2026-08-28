#!/usr/bin/env bash
# Run the gates in order, cheapest first, stopping at the first failure.
#
# Every check is a script beside this one, runnable alone, exit 0 or 1,
# one line per finding in path:line: message form. CI runs these same
# scripts, so a green run here predicts a green run there.
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

WANT_GATE="${1:-}"
WANT_NAME="${2:-}"


# The gates, and the checks each one runs, in the order they run.
#
# Read through a function rather than through eval on a variable name.
# eval hid the lists from every reader, shellcheck included, which
# reported four unused variables that were the whole schedule.
gate_checks() {
  case "$1" in
    # What can be read with no theme present.
    #
    # The template repository holds no theme, so this is the only gate
    # that runs there. Without it, the template's own prose is read by
    # nothing, because a project replaces the README and never sees it.
    template) echo "coverage portable shellcheck comments" ;;
    static)  echo "coverage portable shellcheck templates contract reserved i18n css js comments metadata features" ;;
    build)   echo "package install build versions scale" ;;
    output)  echo "conform validity head a11y perf external nojs feeds search expect visual" ;;
    release) echo "changelog version listing module demo" ;;
    *)       return 1 ;;
  esac
}

if [ "$WANT_GATE" = "--list" ]; then
  for gate in template static build output release; do
    names="$(gate_checks "$gate")"
    printf '%s\n' "$gate"
    for name in $names; do
      printf '  %-12s %s\n' "$name" "tools/scripts/check/$name.sh"
    done
  done
  exit 0
fi

CI="${CI:-}"
pass=0; fail=0; skip=0
red=""; green=""; yellow=""; off=""
if [ -t 1 ]; then
  red="$(printf '\033[31m')"; green="$(printf '\033[32m')"
  yellow="$(printf '\033[33m')"; off="$(printf '\033[0m')"
fi

run_one() {
  # One local a line. Bash expands the whole list before any of it
  # takes effect, so script would have read an outer name.
  local gate="$1"
  local name="$2"
  local script="tools/scripts/check/$name.sh"
  local out status
  if [ ! -x "$script" ]; then
    printf '%s\n' "${yellow}SKIP${off} $gate/$name: no script at $script"
    skip=$((skip + 1))
    return 0
  fi
  out="$("$script" 2>&1)"
  status=$?
  if [ $status -eq 3 ] || printf '%s' "$out" | grep -q '^SKIP '; then
    printf '%s\n' "${yellow}SKIP${off} $gate/$name"
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/    /'
    skip=$((skip + 1))
    return 0
  fi
  if [ $status -ne 0 ]; then
    printf '%s\n' "${red}FAIL${off} $gate/$name"
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/    /'
    fail=$((fail + 1))
    return 1
  fi
  printf '%s\n' "${green}ok${off}   $gate/$name"
  [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/    /'
  pass=$((pass + 1))
  return 0
}

run_gate() {
  local gate="$1"
  local names name
  names="$(gate_checks "$gate")"
  for name in $names; do
    [ -n "$WANT_NAME" ] && [ "$name" != "$WANT_NAME" ] && continue
    run_one "$gate" "$name" || return 1
  done
  return 0
}

gates="static build output"
[ -n "$WANT_GATE" ] && gates="$WANT_GATE"

status=0
for gate in $gates; do
  case "$gate" in
    template|static|build|output|release) ;;
    *) printf '%s\n' "unknown gate: $gate" >&2; exit 2 ;;
  esac
  run_gate "$gate" || { status=1; break; }
done

tally="$pass passed, $fail failed, $skip skipped"
printf '\n%s\n' "$tally"
# The report reads this. It was reading a file nothing wrote, so the
# gate section of every report was empty.
mkdir -p tools/conformance/public
printf '%s\n' "$tally" > tools/conformance/public/tally.txt
# A missing tool is a warning on a workstation. In CI it is a failure,
# because that image carries every tool the pipeline names.
if [ "$skip" -gt 0 ] && [ -n "$CI" ]; then
  printf '%s\n' "a skipped check is a failure under CI" >&2
  status=1
fi
# A run that passed nothing and only skipped reports the missing tool.
# Otherwise it would report a pass that nobody earned.
if [ "$status" -eq 0 ] && [ "$pass" -eq 0 ] && [ "$skip" -gt 0 ]; then
  exit 3
fi
exit $status
