#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHARTS_DIR="$REPO_ROOT/charts"
DEST_DIR="$CHARTS_DIR/randoli-agent/charts"

mkdir -p "$DEST_DIR"

for chart_path in "$CHARTS_DIR"/*/; do
  chart_name="$(basename "$chart_path")"
  [[ "$chart_name" == "randoli-agent" ]] && continue

  echo "==> Building $chart_name"
  helm dependency update "$chart_path"

  # remove previous version
  rm -f "$DEST_DIR/${chart_name}-"[0-9]*.tgz
  helm package "$chart_path" -d "$DEST_DIR"
done

# Fetch remote dependencies of the umbrella chart (e.g. sre-agent from
# helm.randoli.io). Wrapper deps above have no repository: and are left as-is.
#
# Do NOT use `helm dependency update` on the umbrella chart here: Helm 4
# requires dependencies without a repository: field to exist as UNPACKED
# directories in charts/ — vendored .tgz files no longer satisfy it, and the
# command fails with "directory charts/<name> not found". Instead, pull only
# the deps that declare a repository: — and ALWAYS pull: a declared version
# that is not published yet must fail the build here, never silently reuse a
# locally vendored tarball. Release the dependency chart first, then bump.
while read -r dep_name dep_ver dep_repo; do
  echo "==> Fetching $dep_name $dep_ver from $dep_repo"
  rm -f "$DEST_DIR/${dep_name}-"[0-9]*.tgz
  helm pull "$dep_name" --repo "$dep_repo" --version "$dep_ver" --destination "$DEST_DIR"
done < <(awk '
  /^dependencies:/ { in_deps=1; next }
  in_deps && /^[^ ]/ { in_deps=0 }
  in_deps && /^  - name:/ {
    if (name != "" && repo != "") print name, ver, repo
    name=$3; ver=""; repo=""
  }
  in_deps && /^    version:/ { ver=$2 }
  in_deps && /^    repository:/ { gsub(/["'"'"']/, "", $2); repo=$2 }
  END { if (in_deps && name != "" && repo != "") print name, ver, repo }
' "$CHARTS_DIR/randoli-agent/Chart.yaml")

echo "Done. Bundled subcharts:"
ls -1 "$DEST_DIR"/*.tgz
