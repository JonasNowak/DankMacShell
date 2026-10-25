.PHONY: all build build-no-launch debug test dmg icon clean help

all: build

build:
	./build.sh

build-no-launch:
	./build.sh --no-launch

debug:
	./build.sh --debug --no-launch

test:
	./test.sh

dmg:
	./scripts/create-dmg.sh

icon:
	./scripts/generate-icon.sh --force

clean:
	./scripts/clean.sh

help:
	@echo "DankMacShell build and development targets:"
	@echo "  make build            Build, assemble, sign, install dms CLI, and launch app"
	@echo "  make build-no-launch  Build, assemble, sign, and install without launching"
	@echo "  make debug            Build in debug configuration without launching"
	@echo "  make test             Run test suite (Swift Testing)"
	@echo "  make dmg              Package release DMG in dist/"
	@echo "  make icon             Regenerate AppIcon.icns from Support/appicon.svg"
	@echo "  make clean            Remove build artifacts, caches, and dist/"
