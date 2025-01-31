.PHONY: upgrade unused_dependencies format clean test

include ./.env

# Import and export env for edamame_core and edamame_foundation
-include ../secrets/lambda-signature.env
-include ../secrets/foundation.env
-include ../secrets/sentry.env
export

env:
	env

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

macos_debug:
	cargo build
	sudo bash -c "export RUST_BACKTRACE=1; export EDAMAME_LOG_LEVEL=edamame_foundation=debug; rust-lldb ./target/debug/edamame_helper"

windows_debug:
	cargo build
	# This won't work as it requires service context
	#export RUST_BACKTRACE=1; export EDAMAME_LOG_LEVEL=info; ./target/debug/edamame_helper.exe

windows_release:
	cargo build --release && cargo wix --nocapture --no-build

-include ../secrets/azure-sign.env
export
windows_package: windows_release
	AzureSignTool sign -kvu "${AZURE_SIGN_KEY_VAULT_URI}" -kvi "${AZURE_SIGN_CLIENT_ID}" -kvt "${AZURE_SIGN_TENANT_ID}" -kvs "${AZURE_SIGN_CLIENT_SECRET}" -kvc ${AZURE_SIGN_CERT_NAME} -tr http://timestamp.digicert.com -v ./target/wix/edamame_helper*.msi

version:
	cargo set-version $(EDAMAME_HELPER_VERSION)

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
