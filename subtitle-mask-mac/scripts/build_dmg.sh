#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SubtitleMask"
VERSION="1.0.0"
BUILD_DIR="${ROOT_DIR}/release-build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
STAGING_DIR="${BUILD_DIR}/dmg-staging"
RW_DMG="${BUILD_DIR}/${APP_NAME}-temp.dmg"
FINAL_DMG="${ROOT_DIR}/${APP_NAME}-${VERSION}.dmg"
ICON_ICNS="${BUILD_DIR}/AppIcon.icns"
ICON_PNG="${ROOT_DIR}/../icon.png"
PATTERN_DIR="${ROOT_DIR}/../image"

echo "==> cleaning artifacts"
rm -rf "${APP_DIR}" "${STAGING_DIR}" "${RW_DMG}" "${FINAL_DMG}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${STAGING_DIR}"

echo "==> build icon (.icns)"
"${ROOT_DIR}/scripts/make_icns.sh"

echo "==> build release binary"
cd "${ROOT_DIR}"
swift build -c release
cp "${ROOT_DIR}/.build/release/subtitle-mask" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"
cp "${ICON_ICNS}" "${RESOURCES_DIR}/AppIcon.icns"
if [[ -d "${PATTERN_DIR}" ]]; then
  cp -R "${PATTERN_DIR}" "${RESOURCES_DIR}/image"
else
  echo "warning: pattern folder not found: ${PATTERN_DIR}"
fi

cat > "${CONTENTS_DIR}/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>SubtitleMask</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.subtitletool.mask</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>SubtitleMask</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "==> prepare dmg staging"
cp -R "${APP_DIR}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"
mkdir -p "${STAGING_DIR}/.background"
cp "${ICON_PNG}" "${STAGING_DIR}/.background/background.png"

echo "==> create writable dmg"
hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGING_DIR}" -ov -format UDRW "${RW_DMG}"

echo "==> mount and style dmg"
ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "${RW_DMG}")"
DEVICE="$(echo "${ATTACH_OUTPUT}" | awk '/^\/dev\// {dev=$1} END {print dev}')"
MOUNT_POINT="/Volumes/${APP_NAME}"

osascript <<OSA || true
tell application "Finder"
  tell disk "${APP_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, 760, 480}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set background picture of viewOptions to file ".background:background.png"
    set position of item "${APP_NAME}.app" of container window to {200, 220}
    set position of item "Applications" of container window to {520, 220}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
OSA

chmod -R go-w "${MOUNT_POINT}" || true
sync
hdiutil detach "${MOUNT_POINT}" || hdiutil detach "${DEVICE}"

echo "==> convert to compressed dmg"
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if hdiutil convert "${RW_DMG}" -format UDZO -o "${FINAL_DMG}" -ov; then
    break
  fi
  if [[ "${attempt}" -eq 10 ]]; then
    echo "convert failed after retries"
    exit 1
  fi
  sleep 3
done
rm -f "${RW_DMG}"

echo "==> done"
echo "DMG: ${FINAL_DMG}"

