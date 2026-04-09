.PHONY: upgrade unused_dependencies format clean test macos_es_test

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
export
macos_package:
	cargo build --release --target x86_64-apple-darwin
	cargo build --release --target aarch64-apple-darwin
	mkdir -p target/release
	lipo -create -output target/release/edamame_helper \
    target/x86_64-apple-darwin/release/edamame_helper \
    target/aarch64-apple-darwin/release/edamame_helper
	./macos/make-pkg.sh 

macos_publish: macos_package
	./macos/make-distribution-pkg.sh && ./macos/notarization.sh ./target/pkg/edamame-helper.pkg && ./macos/publish.sh

macos_release:
	cargo build --release
	sudo bash -c "export RUST_BACKTRACE=1; export EDAMAME_LOG_LEVEL=edamame_foundation=info; ./target/release/edamame_helper"

macos_debug_console:
	RUSTFLAGS="--cfg tokio_unstable" cargo build
	sudo bash -c "export RUST_BACKTRACE=1; export EDAMAME_LOG_LEVEL=trace; rust-lldb ./target/debug/edamame_helper"

PROV_PROFILE = $(shell ./macos/find-provisioning-profile.sh com.edamametechnologies.edamame-helper 2>/dev/null)

macos_es_test:
	cargo test --test es_entitlement_test --no-run 2>&1
	$(eval ES_BIN := $(shell find target/debug/deps -name 'es_entitlement_test-*' -perm +111 ! -name '*.d' ! -name '*.o' | head -1))
	@echo "Test binary: $(ES_BIN)"
	codesign --force --timestamp --options=runtime \
		--entitlements ./macos/edamame_helper.entitlements \
		-i com.edamametechnologies.edamame-helper \
		--sign "Developer ID Application: Edamame Technologies (WSL782B48J)" "$(ES_BIN)"
	sudo "$(ES_BIN)" --nocapture --test-threads=1

macos_debug:
	cargo build
	codesign --force \
		--entitlements ./macos/edamame_helper_debug.entitlements \
		-i com.edamametechnologies.edamame-helper \
		-s "Developer ID Application: Edamame Technologies (WSL782B48J)" \
		./target/debug/edamame_helper
	sudo bash -c "export RUST_BACKTRACE=1; export EDAMAME_LOG_LEVEL=info,edamame_foundation::runner_cli=debug; rust-lldb ./target/debug/edamame_helper"


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
