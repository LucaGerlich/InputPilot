#!/bin/bash
# InputPilot release pipeline:
#   preflight -> unit tests -> archive -> Developer ID export -> notarize+staple
#   app -> DMG -> sign DMG -> notarize+staple DMG -> Gatekeeper check
#   -> signed appcast -> signature verification
#
# Both the app and the DMG are notarized and stapled: the app so it launches
# offline without contacting Apple, the DMG so Gatekeeper accepts the download.
#
# The appcast is signed (the app sets SURequireSignedFeed). NEVER edit
# appcast.xml by hand afterwards - not even whitespace or a merge-conflict
# fix. Any change breaks the signature and stops updates for every user on
# 1.1.0 or later. Re-run generate_appcast instead.
#
# Usage: Scripts/release.sh <version>   (e.g. Scripts/release.sh 1.1.0)
#
# One-time prerequisites:
#   1. "Developer ID Application" certificate (team T5M4XW2T24) in the
#      login keychain.
#   2. Notary credentials: xcrun notarytool store-credentials InputPilot \
#        --apple-id <apple-id> --team-id T5M4XW2T24
#   3. Sparkle EdDSA keys in the login keychain (generate_keys); the public
#      key is SUPublicEDKey in Config/AppInfo.plist. Back the private key up
#      with `generate_keys -x <file>`: every future appcast needs it.

set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "Usage: Scripts/release.sh <version>  (e.g. 1.1.0)" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$REPO_ROOT/dist/$VERSION"
ARCHIVE="$RELEASE_DIR/InputPilot.xcarchive"
EXPORT_DIR="$RELEASE_DIR/export"
DMG="$RELEASE_DIR/InputPilot-$VERSION.dmg"
FEED_DIR="$RELEASE_DIR/feed"
SOURCE_PACKAGES="$RELEASE_DIR/SourcePackages"
NOTARY_PROFILE="InputPilot"
TEAM_ID="T5M4XW2T24"
SIGNING_IDENTITY="Developer ID Application: Luca Gerlich ($TEAM_ID)"
DOWNLOAD_PREFIX="https://github.com/LucaGerlich/InputPilot/releases/download/v$VERSION/"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

cd "$REPO_ROOT"

# Everything that can stop a release is checked before anything is built, so
# a failure never leaves half a release behind.
echo "==> Preflight"
[[ -z "$(git status --porcelain)" ]] || fail "working tree is not clean. Release only from a clean, committed state."

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[[ "$BRANCH" == "main" ]] || fail "release from main, not '$BRANCH'."

git fetch --quiet origin main --tags
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || fail "HEAD is not origin/main. Pull or push first, so the release matches what is published."

git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null && fail "tag v$VERSION already exists locally."
[[ -z "$(git ls-remote --tags origin "refs/tags/v$VERSION")" ]] || fail "tag v$VERSION already exists on origin."
if gh release view "v$VERSION" >/dev/null 2>&1; then
    fail "GitHub release v$VERSION already exists."
fi

# A re-run signs a new DMG with a different hash and EdDSA signature. If the
# first one was uploaded, the two would no longer match the appcast and cask.
[[ ! -e "$RELEASE_DIR" ]] || fail "$RELEASE_DIR exists. Remove it only if nothing from it was published."

security find-identity -v -p codesigning | grep -qF "$SIGNING_IDENTITY" \
    || fail "'$SIGNING_IDENTITY' is not in the keychain."

grep -A1 "SUPublicEDKey" Config/AppInfo.plist | grep -qE "<string>[^<]+</string>" \
    || fail "SUPublicEDKey in Config/AppInfo.plist is missing or empty; Sparkle would reject every update."

# The project file is the single source of truth for versions. Sparkle
# compares the build number, so a release with an unchanged build number is
# never offered as an update.
echo "==> Checking versions"
BUILD_SETTINGS="$(xcodebuild -project InputPilot.xcodeproj -target InputPilot -configuration Release -showBuildSettings 2>/dev/null)" \
    || fail "could not read build settings."
PROJECT_VERSION="$(echo "$BUILD_SETTINGS" | awk -F' = ' '/ MARKETING_VERSION =/ {print $2; exit}' | tr -d ' ')"
BUILD_NUMBER="$(echo "$BUILD_SETTINGS" | awk -F' = ' '/ CURRENT_PROJECT_VERSION =/ {print $2; exit}' | tr -d ' ')"

[[ "$PROJECT_VERSION" == "$VERSION" ]] \
    || fail "MARKETING_VERSION in the project is '$PROJECT_VERSION' but you asked to release '$VERSION'."

PUBLISHED_BUILD="$( (grep -o '<sparkle:version>[0-9]*' appcast.xml || true) | grep -o '[0-9]*' | sort -n | tail -1)"
if [[ -n "$PUBLISHED_BUILD" && "$BUILD_NUMBER" -le "$PUBLISHED_BUILD" ]]; then
    fail "CURRENT_PROJECT_VERSION is $BUILD_NUMBER but the appcast already advertises build $PUBLISHED_BUILD. Bump it."
fi

echo "Releasing $VERSION (build $BUILD_NUMBER) from $(git rev-parse --short HEAD)"
mkdir -p "$RELEASE_DIR"

# Sparkle's tools come from the exact version Package.resolved pins.
echo "==> Resolving Sparkle tools"
xcodebuild -resolvePackageDependencies -project InputPilot.xcodeproj -scheme InputPilot \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES" >/dev/null
SPARKLE_BIN="$SOURCE_PACKAGES/artifacts/sparkle/Sparkle/bin"
[[ -x "$SPARKLE_BIN/generate_appcast" && -x "$SPARKLE_BIN/sign_update" ]] \
    || fail "Sparkle's generate_appcast and sign_update not found in $SPARKLE_BIN."

# UI tests need an unlocked desktop session and run on CI instead.
echo "==> Running unit tests"
xcodebuild -quiet test -project InputPilot.xcodeproj -scheme InputPilot -destination 'platform=macOS' \
    -only-testing:InputPilotTests CODE_SIGN_IDENTITY=- \
    || fail "unit tests failed."

echo "==> Archiving Release build"
xcodebuild -project InputPilot.xcodeproj \
    -scheme InputPilot \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    archive

echo "==> Exporting with Developer ID"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist Scripts/ExportOptions.plist \
    -exportPath "$EXPORT_DIR"

APP="$EXPORT_DIR/InputPilot.app"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
APP_TEAM="$(codesign -dvv "$APP" 2>&1 | awk -F= '/^TeamIdentifier=/ {print $2}')"
[[ "$APP_TEAM" == "$TEAM_ID" ]] || fail "the exported app is signed by team '$APP_TEAM', expected $TEAM_ID."

# The app is notarized and stapled BEFORE it goes into the DMG. Stapling only
# the DMG leaves the copied-out app without a ticket, so its first launch needs
# a network round-trip to Apple and fails when the user is offline.
echo "==> Notarizing app (this can take a few minutes)"
APP_ZIP="$RELEASE_DIR/InputPilot-app.zip"
ditto -c -k --keepParent "$APP" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
rm -f "$APP_ZIP"

echo "==> Stapling app"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Packaging DMG"
DMG_STAGING="$RELEASE_DIR/dmg"
mkdir -p "$DMG_STAGING"
cp -R "$APP" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "InputPilot" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG"

# An unsigned DMG is rejected by Gatekeeper on its own terms, so sign the
# container too, then notarize and staple it.
echo "==> Signing DMG"
codesign --force --sign "$SIGNING_IDENTITY" --identifier com.lucagerlich.InputPilot.dmg --timestamp "$DMG"
codesign --verify --strict --verbose=2 "$DMG"

echo "==> Notarizing DMG (this can take a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> Verifying Gatekeeper acceptance"
spctl --assess --type open --context context:primary-signature -v "$DMG"

# Only the new DMG goes into the feed folder, next to a copy of the published
# appcast: generate_appcast keeps the earlier items as they are, URLs
# included, and adds this release. It signs the feed because the new build
# requires a signed one. No deltas - each would be another asset to upload.
echo "==> Generating the signed Sparkle appcast"
mkdir -p "$FEED_DIR"
cp "$DMG" "$FEED_DIR/"
cp appcast.xml "$FEED_DIR/appcast.xml"
"$SPARKLE_BIN/generate_appcast" --download-url-prefix "$DOWNLOAD_PREFIX" --maximum-deltas 0 "$FEED_DIR"
cp "$FEED_DIR/appcast.xml" appcast.xml

# generate_appcast only warns when it cannot sign (key missing, Keychain
# prompt denied) and writes an unsigned feed - which 1.1.0+ clients reject.
echo "==> Verifying the appcast and update signatures"
"$SPARKLE_BIN/sign_update" --verify appcast.xml || fail "appcast.xml is not validly signed. Do not publish it."

ENCLOSURE_SIGNATURE="$(/usr/bin/python3 -I - appcast.xml "$VERSION" <<'PY'
import sys
# Parses the appcast generate_appcast just wrote on this machine - not
# untrusted input - so the stdlib parser is fine here.
import xml.etree.ElementTree as ET

ns = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
path, version = sys.argv[1], sys.argv[2]
for item in ET.parse(path).getroot().iter("item"):
    if item.findtext("sparkle:shortVersionString", namespaces=ns) == version:
        print(item.find("enclosure").get("{%s}edSignature" % ns["sparkle"]))
        break
PY
)"
[[ -n "$ENCLOSURE_SIGNATURE" ]] || fail "appcast.xml has no item with an EdDSA signature for $VERSION."
"$SPARKLE_BIN/sign_update" --verify "$DMG" "$ENCLOSURE_SIGNATURE" \
    || fail "$DMG does not match its signature in appcast.xml. Do not publish either."

DMG_SHA="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"

echo ""
echo "==> Done. $DMG is signed, notarized and verified; appcast.xml is updated and signed."
echo ""
echo "Release checklist, in this order:"
echo "  1. git tag -a v$VERSION -m \"InputPilot $VERSION\" $(git rev-parse HEAD) && git push origin v$VERSION"
echo "  2. gh release create v$VERSION \"$DMG\" --verify-tag --title \"InputPilot $VERSION\" --notes <changelog section>"
echo "  3. Immediately after: commit appcast.xml exactly as written (no edits) to main, via PR, and merge."
echo "  4. Homebrew cask (LucaGerlich/homebrew-tap, Casks/inputpilot.rb):"
echo "       version \"$VERSION\""
echo "       sha256 \"$DMG_SHA\""
echo "  5. Check for Updates in the previous version offers $VERSION and installs it."
