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

  rm -f "$DEST_DIR/${chart_name}-"*.tgz
  helm package "$chart_path" -d "$DEST_DIR"
done

echo "Done. Bundled subcharts:"
ls -1 "$DEST_DIR"/*.tgz
