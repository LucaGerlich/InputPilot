#!/bin/bash
# InputPilot release pipeline:
#   archive -> Developer ID export -> notarize+staple app -> DMG -> sign DMG
#   -> notarize+staple DMG -> Gatekeeper check -> appcast
#
# Both the app and the DMG are notarized and stapled: the app so it launches
# offline without contacting Apple, the DMG so Gatekeeper accepts the download.
#
# Usage: Scripts/release.sh <version>   (e.g. Scripts/release.sh 1.0.0)
#
# One-time prerequisites (see AUDIT.md "Parked" section):
#   1. "Developer ID Application" certificate in the login keychain.
#   2. Notary credentials: xcrun notarytool store-credentials InputPilot \
#        --apple-id <apple-id> --team-id T5M4XW2T24
#   3. Sparkle EdDSA keys: run Sparkle's generate_keys once; put the public
#      key into Config/AppInfo.plist (SUPublicEDKey).

set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
	echo "Usage: Scripts/release.sh <version>  (e.g. 1.0.0)" >&2
	exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$REPO_ROOT/dist"
ARCHIVE="$DIST/InputPilot.xcarchive"
EXPORT_DIR="$DIST/export"
DMG="$DIST/InputPilot-$VERSION.dmg"
NOTARY_PROFILE="InputPilot"

cd "$REPO_ROOT"

echo "==> Preflight"
if [[ -n "$(git status --porcelain)" ]]; then
	echo "ERROR: working tree is not clean. Release only from a clean, committed state." >&2
	exit 1
fi

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
	echo "ERROR: no 'Developer ID Application' certificate in the keychain." >&2
	echo "Create one in the Apple Developer portal (team T5M4XW2T24) and install it, then re-run." >&2
	exit 1
fi

if ! grep -q "SUPublicEDKey" Config/AppInfo.plist || grep -A1 "SUPublicEDKey" Config/AppInfo.plist | grep -q "<string></string>"; then
	echo "WARNING: SUPublicEDKey in Config/AppInfo.plist is empty." >&2
	echo "Sparkle updates will not validate until you run generate_keys and fill it in." >&2
fi

# The project file is the single source of truth for versions. Overriding
# MARKETING_VERSION here instead would leave CURRENT_PROJECT_VERSION stale, and
# Sparkle compares the build number - a release with an unchanged build number
# is never offered as an update.
echo "==> Checking versions"
BUILD_SETTINGS="$(xcodebuild -project InputPilot.xcodeproj -target InputPilot -configuration Release -showBuildSettings 2>/dev/null)"
PROJECT_VERSION="$(echo "$BUILD_SETTINGS" | awk -F' = ' '/ MARKETING_VERSION =/ {print $2; exit}' | tr -d ' ')"
BUILD_NUMBER="$(echo "$BUILD_SETTINGS" | awk -F' = ' '/ CURRENT_PROJECT_VERSION =/ {print $2; exit}' | tr -d ' ')"

if [[ "$PROJECT_VERSION" != "$VERSION" ]]; then
	echo "ERROR: MARKETING_VERSION in the project is '$PROJECT_VERSION' but you asked to release '$VERSION'." >&2
	echo "Update MARKETING_VERSION (and CURRENT_PROJECT_VERSION) in the project, commit, then re-run." >&2
	exit 1
fi

if [[ -f appcast.xml ]]; then
	PUBLISHED_BUILD="$(grep -o '<sparkle:version>[0-9]*' appcast.xml | grep -o '[0-9]*' | sort -n | tail -1)"
	if [[ -n "$PUBLISHED_BUILD" && "$BUILD_NUMBER" -le "$PUBLISHED_BUILD" ]]; then
		echo "ERROR: CURRENT_PROJECT_VERSION is $BUILD_NUMBER but the published appcast already advertises build $PUBLISHED_BUILD." >&2
		echo "Sparkle compares build numbers, so this release would never be offered as an update. Bump CURRENT_PROJECT_VERSION." >&2
		exit 1
	fi
fi

echo "Releasing $VERSION (build $BUILD_NUMBER)"

rm -rf "$DIST"
mkdir -p "$DIST"

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

# The app is notarized and stapled BEFORE it goes into the DMG. Stapling only
# the DMG leaves the copied-out app without a ticket, so its first launch needs
# a network round-trip to Apple and fails when the user is offline.
echo "==> Notarizing app (this can take a few minutes)"
APP_ZIP="$DIST/InputPilot-app.zip"
ditto -c -k --keepParent "$APP" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
rm -f "$APP_ZIP"

echo "==> Stapling app"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Packaging DMG"
DMG_STAGING="$DIST/dmg"
mkdir -p "$DMG_STAGING"
cp -R "$APP" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "InputPilot" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG"

# An unsigned DMG is rejected by Gatekeeper on its own terms, so sign the
# container too, then notarize and staple it.
echo "==> Signing DMG"
codesign --force --sign "Developer ID Application" --timestamp "$DMG"
codesign --verify --strict --verbose=2 "$DMG"

echo "==> Notarizing DMG (this can take a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> Verifying Gatekeeper acceptance"
spctl --assess --type open --context context:primary-signature -v "$DMG"

echo "==> Generating Sparkle appcast"
# Sparkle downloads the DMG from the GitHub release asset URL, not from the
# repo tree, so the enclosure URLs must carry that prefix.
DOWNLOAD_PREFIX="https://github.com/LucaGerlich/InputPilot/releases/download/v$VERSION/"
GENERATE_APPCAST="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*artifacts*Sparkle*/bin/generate_appcast" -print -quit 2>/dev/null || true)"
if [[ -n "$GENERATE_APPCAST" ]]; then
	"$GENERATE_APPCAST" --download-url-prefix "$DOWNLOAD_PREFIX" "$DIST"
	echo "Appcast written to $DIST/appcast.xml"
else
	echo "WARNING: generate_appcast not found in DerivedData; build once in Xcode or download Sparkle's tools, then run:" >&2
	echo "  generate_appcast --download-url-prefix $DOWNLOAD_PREFIX $DIST" >&2
fi

echo ""
echo "==> Done. Release checklist:"
echo "  1. git tag v$VERSION && git push origin v$VERSION"
echo "  2. Create a GitHub Release for v$VERSION and attach: $DMG"
echo "  3. Commit the updated appcast.xml to main (the SUFeedURL points at it)."
echo "  4. Verify Gatekeeper on another Mac: spctl --assess --type open --context context:primary-signature -v $DMG"
