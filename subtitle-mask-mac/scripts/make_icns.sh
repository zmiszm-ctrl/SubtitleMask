#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_PNG="${ROOT_DIR}/../icon.png"
ICONSET_DIR="${ROOT_DIR}/release-build/AppIcon.iconset"
ICNS_PATH="${ROOT_DIR}/release-build/AppIcon.icns"

if [[ ! -f "${SOURCE_PNG}" ]]; then
  echo "icon source not found: ${SOURCE_PNG}"
  exit 1
fi

rm -rf "${ICONSET_DIR}" "${ICNS_PATH}"
mkdir -p "${ICONSET_DIR}"

sips -z 16 16 "${SOURCE_PNG}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
sips -z 32 32 "${SOURCE_PNG}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "${SOURCE_PNG}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
sips -z 64 64 "${SOURCE_PNG}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "${SOURCE_PNG}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
sips -z 256 256 "${SOURCE_PNG}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "${SOURCE_PNG}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
sips -z 512 512 "${SOURCE_PNG}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "${SOURCE_PNG}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
sips -z 1024 1024 "${SOURCE_PNG}" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null

iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_PATH}"
echo "icon generated: ${ICNS_PATH}"

