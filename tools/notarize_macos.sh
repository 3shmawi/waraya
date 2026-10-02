#!/usr/bin/env bash
# Signs the macOS app with the Developer ID certificate, has Apple notarize
# it, staples the ticket, and zips it.
#
#   tools/notarize_macos.sh build/macos/Build/Products/Release/waraya.app out/waraya-1.0.0-macos.zip
#
# Run by .github/workflows/release.yml on a macOS runner. Reads:
#   MACOS_DEVELOPER_ID_P12_BASE64   the "Developer ID Application" certificate
#   MACOS_DEVELOPER_ID_P12_PASSWORD with its private key, as a .p12
#   ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_P8_BASE64
#                                   the App Store Connect API key the iOS
#                                   uploads already use; notarytool takes it
#
# Without this a downloaded waraya.app is refused by Gatekeeper on a double
# click ("cannot be opened because the developer cannot be verified"), and
# the only way in is right-click -> Open, which most people never try.
# Notarized and stapled, it opens like any other app, offline included —
# the stapled ticket is what Gatekeeper checks when it cannot reach Apple.
set -euo pipefail

app=$1
zip=$2
: "${MACOS_DEVELOPER_ID_P12_BASE64:?}" "${MACOS_DEVELOPER_ID_P12_PASSWORD:?}"
: "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_P8_BASE64:?}"

work=$(mktemp -d)
keychain="$work/signing.keychain-db"
keychain_password=$(uuidgen)
# The certificate, the API key and the keychain live for this script only.
trap 'security delete-keychain "$keychain" 2>/dev/null || true; rm -rf "$work"' EXIT

# A keychain of its own, unlocked, holding only the certificate, and put on
# the search list so codesign can find it.
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
echo "$MACOS_DEVELOPER_ID_P12_BASE64" | base64 --decode > "$work/developer-id.p12"
security import "$work/developer-id.p12" -k "$keychain" \
  -P "$MACOS_DEVELOPER_ID_P12_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s \
  -k "$keychain_password" "$keychain" >/dev/null
# shellcheck disable=SC2046 # the existing list, one word per keychain
security list-keychains -d user -s "$keychain" $(security list-keychains -d user | tr -d '"')

identity=$(security find-identity -v -p codesigning "$keychain" \
  | awk '/Developer ID Application/ { print $2; exit }')
if [ -z "$identity" ]; then
  echo "::error::the .p12 has no \"Developer ID Application\" certificate (an \"Apple Distribution\" one is for the App Store, not for this)"
  exit 1
fi

# Inside out: every framework and library first, then the app around them.
# Hardened runtime and a secure timestamp on all of it, which notarization
# requires; the entitlements (sandbox, outgoing network) on the app only.
find "$app/Contents/Frameworks" -depth \( -name '*.framework' -o -name '*.dylib' \) -print0 \
  | while IFS= read -r -d '' item; do
      codesign --force --options runtime --timestamp --sign "$identity" "$item"
    done
codesign --force --options runtime --timestamp \
  --entitlements macos/Runner/Release.entitlements \
  --sign "$identity" "$app"
codesign --verify --strict --deep --verbose=2 "$app"

# Apple's check. --wait blocks until it is decided — usually a few minutes.
echo "$ASC_KEY_P8_BASE64" | base64 --decode > "$work/AuthKey.p8"
ditto -c -k --keepParent "$app" "$work/notarize.zip"
xcrun notarytool submit "$work/notarize.zip" \
  --key "$work/AuthKey.p8" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" \
  --wait --timeout 45m --output-format json > "$work/result.json"
cat "$work/result.json"
status=$(plutil -extract status raw -o - "$work/result.json")
if [ "$status" != "Accepted" ]; then
  # The log says which file, and why — the one thing worth printing.
  id=$(plutil -extract id raw -o - "$work/result.json")
  xcrun notarytool log "$id" \
    --key "$work/AuthKey.p8" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" || true
  echo "::error::notarization: $status"
  exit 1
fi

# The ticket goes into the app itself, so it opens without asking Apple.
xcrun stapler staple "$app"
spctl --assess --type execute --verbose=2 "$app"

mkdir -p "$(dirname "$zip")"
ditto -c -k --keepParent "$app" "$zip"
echo "signed, notarized and stapled: $zip"
