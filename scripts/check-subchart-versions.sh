#!/usr/bin/env bash
#
# Regression guard: every dependency declared in a chart's Chart.yaml must
# semver-match the subchart actually vendored in that chart's charts/ dir.
#
# Run after scripts/build-subcharts.sh so charts/*/charts/ is populated.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHARTS_DIR="$REPO_ROOT/charts"

failures=0

fail() {
  printf '  \033[31mFAIL\033[0m %s\n' "$1"
  failures=$((failures + 1))
}

for chart_path in "$CHARTS_DIR"/*/; do
  chart_name="$(basename "$chart_path")"
  [[ -f "$chart_path/Chart.yaml" ]] || continue

  # Charts with no dependencies: block absent means nothing to check.
  grep -qE '^dependencies:' "$chart_path/Chart.yaml" || continue

  echo "==> $chart_name"

  # helm dependency list is the authoritative check: it applies Helm's own
  # semver matching, so we never reimplement (and drift from) that logic.
  out="$(helm dependency list "$chart_path" 2>&1)"
  rc=$?
  if [[ $rc -ne 0 ]]; then
    fail "$chart_name: 'helm dependency list' exited $rc"
    printf '%s\n' "$out" | sed 's/^/       /'
    continue
  fi

  # Any dependency whose STATUS is not ok/unpacked is a mismatch.
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    dep="$(printf '%s' "$line" | cut -f1 | sed 's/ *$//')"
    ver="$(printf '%s' "$line" | cut -f2 | sed 's/ *$//')"
    status="$(printf '%s' "$line" | awk -F'\t' '{print $NF}' | sed 's/^ *//; s/ *$//')"

    case "$status" in
      ok|unpacked) ;;
      *)
        fail "$chart_name -> $dep: declared '$ver' but helm reports '$status'"
        fail_hint="$chart_path/charts/"
        if compgen -G "$fail_hint$dep-*.tgz" >/dev/null; then
          actual="$(tar -xzOf "$fail_hint$dep-"*.tgz "$dep/Chart.yaml" 2>/dev/null \
                    | awk '/^version:/ {print $2; exit}')"
          [[ -n "$actual" ]] && printf '       vendored version is: %s\n' "$actual"
        fi
        ;;
    esac
  done < <(printf '%s\n' "$out" | grep -vE '^(NAME|WARNING:|$)')

  # An undeclared tarball in charts/ is still loaded and rendered by Helm, with
  # no tag or condition gating it. Usually a stale artifact from another branch.
  while IFS= read -r warn; do
    fail "$chart_name: $warn"
    echo "       run scripts/build-subcharts.sh on a clean charts/ dir"
  done < <(printf '%s\n' "$out" | grep -oE '"[^"]+" is not in Chart.yaml' || true)
done

echo
if [[ $failures -gt 0 ]]; then
  printf '\033[31m%s dependency version problem(s) found.\033[0m\n' "$failures"
  echo "Fix: set each Chart.yaml dependency version to the vendored subchart's"
  echo "own version (charts/<dep>/Chart.yaml), then re-run scripts/build-subcharts.sh."
  exit 1
fi

printf '\033[32mAll declared dependency versions match their vendored subcharts.\033[0m\n'
