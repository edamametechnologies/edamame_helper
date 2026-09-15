.PHONY: macos_release macos_debug macos_debug_console upgrade unused_dependencies format clean test macos_es_test install_provisioning

# Import and export env for edamame_core and edamame_foundation
-include ../secrets/lambda-signature.env
-include ../secrets/foundation.env
-include ../secrets/sentry.env
export

delcachedignore:
	# Remove files from the index (do not delete them from the filesystem) - limited to the base .gitignore
	git ls-files -i -c --exclude-from=.gitignore | xargs git rm --cached

-include ../secrets/aws-writer.env
-include ../secrets/apple-sign.env
-include ../secrets/apple-provisioning.env
export

install_provisioning:
	@test -n "$(APPLE_ES_HELPER_PROVISIONING_PROFILE)" || (echo "Missing APPLE_ES_HELPER_PROVISIONING_PROFILE -- source ../secrets/apple-provisioning.env" && exit 1)
	mkdir -p "$(HOME)/Library/MobileDevice/Provisioning Profiles"
	echo "$(APPLE_ES_HELPER_PROVISIONING_PROFILE)" | base64 --decode > "$(HOME)/Library/MobileDevice/Provisioning Profiles/EDAMAME_Helper.provisionprofile"
	sudo mkdir -p "/Library/MobileDevice/Provisioning Profiles"
	sudo cp "$(HOME)/Library/MobileDevice/Provisioning Profiles/EDAMAME_Helper.provisionprofile" "/Library/MobileDevice/Provisioning Profiles/EDAMAME_Helper.provisionprofile"
	@echo "Provisioning profile installed (user + system-wide)."

macos_package:
	cargo build --release --target x86_64-apple-darwin
	cargo build --release --target aarch64-apple-darwin
	mkdir -p target/release
	lipo -create -output target/release/edamame_helper \
    target/x86_64-apple-darwin/release/edamame_helper \
    target/aarch64-apple-darwin/release/edamame_helper
	./macos/make-pkg.sh --provisioning-profile "$(HOME)/Library/MobileDevice/Provisioning Profiles/EDAMAME_Helper.provisionprofile"

macos_publish: macos_package
	./macos/make-distribution-pkg.sh && ./macos/notarization.sh ./target/pkg/edamame-helper.pkg && ./macos/publish.sh

PROV_PROFILE = $(shell ./macos/find-provisioning-profile.sh com.edamametechnologies.edamame-helper 2>/dev/null)
SYSTEM_PROV_PROFILE = /Library/MobileDevice/Provisioning Profiles/EDAMAME_Helper.provisionprofile
DEBUG_APP = ./target/debug/edamame_helper.app
RELEASE_APP = ./target/release/edamame_helper.app

# macOS 15+/26 AMFI no longer treats a system-wide profile as authorizing a bare
# Mach-O with restricted ES entitlements. Stage a minimal .app with an embedded
# profile (same shape as make-pkg.sh) before signing/launching under sudo. A
# helper launched as a bare binary silently loses Endpoint Security and every
# file event falls back to the lsof attribution tier.
#   $(1) built binary   $(2) app bundle path   $(3) entitlements file
#   $(4) extra codesign flags (release: --options=runtime, as make-pkg.sh)
define stage_helper_app
	@PROFILE="$(PROV_PROFILE)"; \
	if [ -z "$$PROFILE" ] && [ -f "$(SYSTEM_PROV_PROFILE)" ]; then PROFILE="$(SYSTEM_PROV_PROFILE)"; fi; \
	if [ -z "$$PROFILE" ] || [ ! -f "$$PROFILE" ]; then \
		echo "Missing ES provisioning profile. Run: make install_provisioning" >&2; \
		exit 1; \
	fi; \
	rm -rf "$(2)"; \
	mkdir -p "$(2)/Contents/MacOS"; \
	cp "$(1)" "$(2)/Contents/MacOS/edamame_helper"; \
	cp "$$PROFILE" "$(2)/Contents/embedded.provisionprofile"; \
	printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0"><dict>' \
		'<key>CFBundleExecutable</key><string>edamame_helper</string>' \
		'<key>CFBundleIdentifier</key><string>com.edamametechnologies.edamame-helper</string>' \
		'<key>CFBundleName</key><string>EDAMAME Helper</string>' \
		'<key>CFBundlePackageType</key><string>APPL</string>' \
		'<key>CFBundleShortVersionString</key><string>0.0.1</string>' \
		'<key>CFBundleVersion</key><string>0.0.1</string>' \
		'<key>LSBackgroundOnly</key><true/>' \
		'</dict></plist>' > "$(2)/Contents/Info.plist"; \
	codesign --force $(4) \
		--entitlements $(3) \
		-i com.edamametechnologies.edamame-helper \
		-s "Developer ID Application: Edamame Technologies (WSL782B48J)" \
		"$(2)"; \
	echo "Staged helper app: $(2) (profile=$$PROFILE, entitlements=$(3))"
endef

# Release binary, staged and signed exactly like the shipped pkg (release
# entitlements, hardened runtime) so a locally run release helper has ES.
macos_release:
	cargo build --release
	$(call stage_helper_app,./target/release/edamame_helper,$(RELEASE_APP),./macos/edamame_helper.entitlements,--options=runtime)
	sudo bash -c "export RUST_BACKTRACE=1; export EDAMAME_LOG_LEVEL=edamame_foundation=info; $(RELEASE_APP)/Contents/MacOS/edamame_helper"

macos_debug_console:
	RUSTFLAGS="--cfg tokio_unstable" cargo build
	$(call stage_helper_app,./target/debug/edamame_helper,$(DEBUG_APP),./macos/edamame_helper_debug.entitlements,)
	sudo bash -c "export RUST_BACKTRACE=1; export EDAMAME_LOG_LEVEL=trace; rust-lldb $(DEBUG_APP)/Contents/MacOS/edamame_helper"

macos_debug:
	cargo build
	$(call stage_helper_app,./target/debug/edamame_helper,$(DEBUG_APP),./macos/edamame_helper_debug.entitlements,)
	sudo bash -c "export RUST_BACKTRACE=1; export EDAMAME_LOG_LEVEL=info,edamame_foundation::runner_cli=debug; rust-lldb $(DEBUG_APP)/Contents/MacOS/edamame_helper"


macos_profile:
	cargo build
	sudo -E cargo instruments -t "CPU Profiler" --time-limit 200000

windows_debug:
	cargo build
	export RUST_BACKTRACE=1; export EDAMAME_LOG_LEVEL=info; ./target/debug/edamame_helper.exe

windows_release:
	cargo build --release && cargo wix --nocapture --no-build

-include ../secrets/azure-sign.env
export
windows_package: windows_release
	AzureSignTool sign -kvu "${AZURE_SIGN_KEY_VAULT_URI}" -kvi "${AZURE_SIGN_CLIENT_ID}" -kvt "${AZURE_SIGN_TENANT_ID}" -kvs "${AZURE_SIGN_CLIENT_SECRET}" -kvc ${AZURE_SIGN_CERT_NAME} -tr http://timestamp.digicert.com -v ./target/wix/edamame_helper*.msi

upgrade:
	rustup update
	cargo install -f cargo-upgrades
	cargo upgrades
	cargo update

unused_dependencies:
	cargo +nightly udeps

format:
	cargo fmt

clean:
	cargo clean
	rm -rf ./build/
	rm -rf ./target/

test:
	cargo test
