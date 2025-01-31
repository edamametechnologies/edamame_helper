#!/bin/bash

# Verify that all required environment variables are properly set
if [ -z "${APPLE_DEVELOPMENT_CER}" ]; then
  echo "Error: APPLE_DEVELOPMENT_CER is not set."
  exit 1
fi

if [ -z "${APPLE_DEVELOPMENT_KEY}" ]; then
  echo "Error: APPLE_DEVELOPMENT_KEY is not set."
  exit 1
fi

if [ -z "${APPLE_DEVELOPER_ID_INSTALLER_CER}" ]; then
  echo "Error: APPLE_DEVELOPER_ID_INSTALLER_CER is not set."
  exit 1
fi

if [ -z "${APPLE_DEVELOPER_ID_INSTALLER_KEY}" ]; then
  echo "Error: APPLE_DEVELOPER_ID_INSTALLER_KEY is not set."
  exit 1
fi

if [ -z "${APPLE_DEVELOPER_ID_APPLICATION_CER}" ]; then
  echo "Error: APPLE_DEVELOPER_ID_APPLICATION_CER is not set."
  exit 1
fi

if [ -z "${APPLE_DEVELOPER_ID_APPLICATION_KEY}" ]; then
  echo "Error: APPLE_DEVELOPER_ID_APPLICATION_KEY is not set."
  exit 1
fi

if [ -z "${APPLE_P12_PASSWORD}" ]; then
  echo "Error: APPLE_P12_PASSWORD is not set."
  exit 1
fi

if [ -z "${MACOS_KEYCHAIN_PASSWORD}" ]; then
  echo "Error: MACOS_KEYCHAIN_PASSWORD is not set."
  exit 1
fi

# Create certificate files from secrets base64
echo "${APPLE_DEVELOPMENT_CER}" | base64 --decode > certificate_dev.cer
echo "${APPLE_DEVELOPMENT_KEY}" | base64 --decode > certificate_dev.key
echo "${APPLE_DEVELOPER_ID_INSTALLER_CER}" | base64 --decode > certificate_installer.cer
echo "${APPLE_DEVELOPER_ID_INSTALLER_KEY}" | base64 --decode > certificate_installer.key
echo "${APPLE_DEVELOPER_ID_APPLICATION_CER}" | base64 --decode > certificate_application.cer
echo "${APPLE_DEVELOPER_ID_APPLICATION_KEY}" | base64 --decode > certificate_application.key

# Create p12 files
openssl pkcs12 -export -name zup -in certificate_dev.cer -inkey certificate_dev.key -passin pass:"${APPLE_P12_PASSWORD}" -out certificate_dev.p12 -passout pass:"${MACOS_KEYCHAIN_PASSWORD}"
openssl pkcs12 -export -name zup -in certificate_installer.cer -inkey certificate_installer.key -passin pass:"${APPLE_P12_PASSWORD}" -out certificate_installer.p12 -passout pass:"${MACOS_KEYCHAIN_PASSWORD}"
openssl pkcs12 -export -name zup -in certificate_application.cer -inkey certificate_application.key -passin pass:"${APPLE_P12_PASSWORD}" -out certificate_application.p12 -passout pass:"${MACOS_KEYCHAIN_PASSWORD}"

# Configure Keychain
KEYCHAIN_PATH=/tmp/app-signing.keychain-db
rm -f "$KEYCHAIN_PATH"
security create-keychain -p "${MACOS_KEYCHAIN_PASSWORD}" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "${MACOS_KEYCHAIN_PASSWORD}" "$KEYCHAIN_PATH"

# Import certificates into the Keychain
security import certificate_dev.p12 -P "${APPLE_P12_PASSWORD}" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
security import certificate_installer.p12 -P "${APPLE_P12_PASSWORD}" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
security import certificate_application.p12 -P "${APPLE_P12_PASSWORD}" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"

rm -f certificate_dev.cer certificate_dev.key certificate_installer.cer certificate_installer.key \
      certificate_application.cer certificate_application.key certificate_dev.p12 \
      certificate_installer.p12 certificate_application.p12

# Verify Keychain
security list-keychain -d user -s $KEYCHAIN_PATH

# Store notarization credentials
echo "${APPLE_APPSTORE_CONNECT_API_KEY}" | base64 --decode > appstore_connect_api_key.p8
xcrun notarytool store-credentials -k appstore_connect_api_key.p8 -d "${APPLE_APPSTORE_CONNECT_API_KEY_ID}" -i "${APPLE_APPSTORE_CONNECT_API_ISSUER_ID}" Edamame
rm -f appstore_connect_api_key.p8