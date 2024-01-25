.PHONY:

# Env files shall be within the project directory

include ./.env

env:
	env

delcachedignore:
	# Remove files from the index (do not delete them from the filesystem) - limited to the base .gitignore
	git ls-files -i -c --exclude-from=.gitignore | xargs git rm --cached

clean:
	cargo clean
	rm -rf ./build/
	rm -rf ./target/
	rm -rf ./windows/edamame_helper/target
	rm -rf ./macos/target

macos_publish:
	cd ../edamame_foundation; ./update-threats.sh macOS
	cargo update
	cat ./Cargo.toml | sed 's/\"cdylib\"/\"staticlib\"/g' > ./Cargo.toml.static; cp ./Cargo.toml.static ./Cargo.toml
	xcodebuild -project ./macos/edamame_helper_xcode/edamame_helper_xcode.xcodeproj -scheme edamame_helper -configuration Release
	set -a; source ../edamame/secrets/aws-writer.env; set +a; cd ./macos; ./make-pkg.sh && ./make-distribution-pkg.sh && ./notarization.sh && ./publish.sh

macos_debug:
	cd ../edamame_foundation; ./update-threats.sh macOS
	cargo update
	cat ./Cargo.toml | sed 's/\"cdylib\"/\"staticlib\"/g' > ./Cargo.toml.static; cp ./Cargo.toml.static ./Cargo.toml
	xcodebuild -project ./macos/edamame_helper_xcode/edamame_helper_xcode.xcodeproj -scheme edamame_helper -configuration Debug
	# Sign again as the signed binary is somewhere else
	codesign -s "Developer ID Application: EDAMAME Technologies (WSL782B48J)" ./macos/target/edamame_helper
	sudo bash -c "export RUST_BACKTRACE=1; export EDAMAME_LOG_LEVEL=info; rust-lldb ./macos/target/edamame_helper"

macos_trace:
	cd ../edamame_foundation; ./update-threats.sh macOS
	cargo update
	cat ./Cargo.toml | sed 's/\"cdylib\"/\"staticlib\"/g' > ./Cargo.toml.static; cp ./Cargo.toml.static ./Cargo.toml
	xcodebuild -project ./macos/edamame_helper_xcode/edamame_helper_xcode.xcodeproj -scheme edamame_helper -configuration Debug
	sudo bash -c "export RUST_BACKTRACE=1; export EDAMAME_LOG_LEVEL=trace; rust-lldb ./macos/target/edamame_helper"

windows_debug:
	cd ../edamame_foundation; ./update-threats.sh Windows
	cd ../edamame_foundation; cat ./Cargo.toml | sed 's/\"cdylib\"/\"staticlib\"/g' > ./Cargo.toml.static; cp ./Cargo.toml.static ./Cargo.toml
	cargo update
	cat ./Cargo.toml | sed 's/\"cdylib\"/\"staticlib\"/g' > ./Cargo.toml.static; cp ./Cargo.toml.static ./Cargo.toml
	cd ./windows/edamame_helper_windows; cargo build
	# This won't work as it requires service context
	#export RUST_BACKTRACE=1; export EDAMAME_LOG_LEVEL=info; ./windows/edamame_helper_windows/target/debug/edamame_helper_windows.exe

windows_release:
	cd ../edamame_foundation; ./update-threats.sh Windows
	cargo update
	cat ./Cargo.toml | sed 's/\"cdylib\"/\"staticlib\"/g' > ./Cargo.toml.static; cp ./Cargo.toml.static ./Cargo.toml
	cd ./windows/edamame_helper_windows; cargo build --release && mv ./target/release/edamame_helper_windows.exe ./target/release/edamame_helper.exe && cargo wix --nocapture --no-build
	AzureSignTool sign -kvt "${AZURE_SIGN_TENANT_ID}" -kvu "${AZURE_SIGN_KEY_VAULT_URI}" -kvi "${AZURE_SIGN_CLIENT_ID}" -kvs "${AZURE_SIGN_CLIENT_SECRET}" -kvc "${AZURE_SIGN_CERT_NAME}" -tr http://timestamp.digicert.com -v ./windows/edamame_helper_windows/target/wix/edamame_helper*.msi

version:
	cargo set-version $(EDAMAME_HELPER_VERSION)
	cd ./windows/edamame_helper_windows; cargo set-version $(EDAMAME_HELPER_VERSION)
	sed -i "" "s/MARKETING_VERSION = .*/MARKETING_VERSION = $(EDAMAME_HELPER_VERSION);/g" ../edamame_helper/edamame_helper.xcodeproj/project.pbxproj
	sed -i "" "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $(EDAMAME_HELPER_VERSION);/g" ../edamame_helper/edamame_helper.xcodeproj/project.pbxproj
	sed -i "" "s/MARKETING_VERSION = .*/MARKETING_VERSION = $(EDAMAME_HELPER_VERSION);/g" ../edamame_helper/macos/edamame_helper_xcode/edamame_helper_xcode.xcodeproj/project.pbxproj
	sed -i "" "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $(EDAMAME_HELPER_VERSION);/g" ../edamame_helper/macos/edamame_helper_xcode/edamame_helper_xcode.xcodeproj/project.pbxproj

upgrade:
	rustup update
	cargo install -f cargo-upgrades
	cargo upgrades
	cargo update
	cd windows/edamame_helper_windows; cargo upgrades
	cd windows/edamame_helper_windows; cargo update
	pod repo update

unused_dependencies:
	cargo +nightly udeps

