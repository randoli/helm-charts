#!/usr/bin/env bash
set -euo pipefail

# Validates a tag-triggered chart release:
#   1. Tag must be X.Y.Z (stable) or X.Y.Z-(rc|alpha|beta).N (pre-release).
#      No 'v' prefix — semver doesn't require one, and dropping it makes the
#      git tag identical to the Helm chart version.
#   2. charts/randoli-agent/Chart.yaml version must match the tag exactly.
#   3. Tagged commit must be reachable from the right branch:
#        stable      -> main only
#        pre-release -> main or pre-release
#
# Reads the tag from GITHUB_REF_NAME (set by GitHub Actions on tag push) and
# falls back to the tag pointing at HEAD for local runs. Writes 'version' and
# 'is_stable' to $GITHUB_OUTPUT when running in Actions.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_FILE="$REPO_ROOT/charts/randoli-agent/Chart.yaml"

version="${GITHUB_REF_NAME:-$(git -C "$REPO_ROOT" tag --points-at HEAD | head -n1)}"
if [[ -z "$version" ]]; then
  echo "::error::No tag found. This workflow expects to run on a semver tag push (e.g. 1.0.0, 1.0.0-rc.1)."
  exit 1
fi
echo "Tag: $version"

stable_re='^[0-9]+\.[0-9]+\.[0-9]+$'
prerelease_re='^[0-9]+\.[0-9]+\.[0-9]+-(rc|alpha|beta)\.[0-9]+$'

if [[ "$version" =~ $stable_re ]]; then
  is_stable=true
elif [[ "$version" =~ $prerelease_re ]]; then
  is_stable=false
else
  echo "::error::Tag must be X.Y.Z or X.Y.Z-(rc|alpha|beta).N (e.g. 1.0.0, 1.0.0-rc.1); got '$version'."
  exit 1
fi

chart_version=$(awk '/^version:/ {print $2; exit}' "$CHART_FILE" | tr -d '"')
if [[ "$chart_version" != "$version" ]]; then
  echo "::error::Tag '$version' does not match ${CHART_FILE#"$REPO_ROOT/"} version '$chart_version'. Bump Chart.yaml to '$version' (or re-tag) and re-push."
  exit 1
fi

head_sha=$(git -C "$REPO_ROOT" rev-parse HEAD)
contains=$(git -C "$REPO_ROOT" branch -r --contains "$head_sha" --format '%(refname:short)' | sed 's|^origin/||')
echo "Tagged commit ${head_sha:0:8} is on remote branches:"
echo "$contains" | sed 's/^/  /'

on_main=false
on_prerelease=false
grep -qxF main         <<<"$contains" && on_main=true
grep -qxF pre-release  <<<"$contains" && on_prerelease=true

if [[ "$is_stable" == "true" ]]; then
  if [[ "$on_main" != "true" ]]; then
    echo "::error::Stable tag '$tag' must point to a commit reachable from 'main'."
    exit 1
  fi
else
  if [[ "$on_main" != "true" && "$on_prerelease" != "true" ]]; then
    echo "::error::Pre-release tag '$tag' must point to a commit reachable from 'main' or 'pre-release'."
    exit 1
  fi
fi

echo "Validation OK (version=$version, is_stable=$is_stable)."

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "version=${version}" >>"$GITHUB_OUTPUT"
  echo "is_stable=${is_stable}" >>"$GITHUB_OUTPUT"
fi
