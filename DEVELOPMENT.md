# Development

## Publishing a new chart version

Releases are automated. Push your changes to `main` and `.github/workflows/release.yaml` will package the chart, create a GitHub Release with the tarball as an asset, update `index.yaml` on the `gh-pages` branch, and push to GHCR.

To cut a release:

1. Bump `version` in `charts/randoli-agent/Chart.yaml` (and any wrapper `Chart.yaml` you changed).
2. If you touched a wrapper, run `helm dependency update charts/<name>` and `helm package charts/<name> -d charts/randoli-agent/charts/` so the bundled tarball is current.
3. Commit and push to `main`.

## Local dry-run

```
make package        # rebuilds wrappers and packages randoli-agent locally
make template       # renders templates with all feature tags enabled
make lint           # helm lint on the umbrella chart
```

The local `.tgz` is for inspection only — do not commit it, and do not regenerate a root-level `index.yaml`. The published index lives on the `gh-pages` branch and is maintained by CI.
