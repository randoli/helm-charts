CHART_DIR  := charts/randoli-agent
CHART_NAME := randoli-agent
VERSION    := $(shell awk '/^version:/ {print $$2}' $(CHART_DIR)/Chart.yaml)

.PHONY: all subcharts package lint template clean help

# Releases are published by .github/workflows/release.yaml on push to main:
# chart-releaser-action creates a GitHub Release per tarball and updates
# index.yaml on the gh-pages branch. These targets are for local builds
# and dry-runs only — do not regenerate index.yaml here.
all: package

## subcharts: rebuild every wrapper subchart into randoli-agent/charts/
subcharts:
	./scripts/build-subcharts.sh

## package: package randoli-agent into $(CHART_NAME)-$(VERSION).tgz
package: subcharts
	helm package $(CHART_DIR)

## lint: lint the umbrella chart
lint:
	helm lint $(CHART_DIR)

## template: dry-run render with all feature tags enabled
template:
	helm template randoli $(CHART_DIR) \
		--set tags.observability=true \
		--set tags.costManagement=true \
		--set tags.security=true

## clean: remove the packaged tarball for the current version
clean:
	rm -f $(CHART_NAME)-$(VERSION).tgz

help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'
