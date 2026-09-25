NAME    := molt-chromium
VERSION := $(shell jq -r .version package.json)
# package.json version is <jbr>-<build>[-<revision>], e.g. 21.0.11-b1163.116-1:
# the exact JetBrains Runtime (jcef) build the Molt Code desktop app ships on,
# plus an optional packaging revision.
JBR       := $(word 1,$(subst -, ,$(VERSION)))
JBR_BUILD := $(word 2,$(subst -, ,$(VERSION)))

PLATFORMS := darwin-arm64 darwin-x64 linux-x64 linux-arm64
CACHE     ?= $(or $(XDG_CACHE_HOME),$(HOME)/.cache)/molt-chromium

.PHONY: dist release clean

# out/: one npm-layout plugin tarball per platform (package/ root) and
# artifacts.json with url/sha256/size per platform for the Molt catalog.
dist:
	@rm -rf build out && mkdir -p build out "$(CACHE)"
	@for p in $(PLATFORMS); do \
		./scripts/package.sh "$$p" "$(JBR)" "$(JBR_BUILD)" "$(CACHE)" build "out/$(NAME)-$(VERSION)-$$p.tgz" || exit 1; \
	done
	@./scripts/artifacts.sh "$(NAME)" "$(VERSION)" $(PLATFORMS) > out/artifacts.json
	@cat out/artifacts.json

# Publishes the existing out/ as GitHub release v$(VERSION) (run `make dist`
# first). No rebuild here: the Molt catalog pins these exact tarballs' sha256,
# and assets are never replaced.
release:
	@test -f out/artifacts.json || (echo "run make dist first"; exit 1)
	gh release create "v$(VERSION)" out/*.tgz --repo moltcode/$(NAME) \
		--title "$(NAME) $(VERSION)" \
		--notes "Chromium (JetBrains Runtime jcef $(JBR)-$(JBR_BUILD), out-of-process cef_server) for Molt Code HTML previews. macOS bundles are re-signed and notarized with Molt's Developer ID (Utpun Tech Labs, ZW445NH299); Linux files are JetBrains' unmodified."

clean:
	rm -rf build out
