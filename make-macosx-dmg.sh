#!/bin/bash
set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <target>"
    echo "Example: $0 release"
    echo "Valid targets: release, debug"
    exit 1
fi

if [ "$1" == "release" ]; then
    TARGET_NAME="release"
elif [ "$1" == "debug" ]; then
    TARGET_NAME="debug"
else
    echo "Invalid target: $1"
    echo "Valid targets: release, debug"
    exit 1
fi

CURRENT_ARCH="arm64"
OBJROOT="build"
PRODUCT_NAME="RealRTCW"
WRAPPER_NAME="${PRODUCT_NAME}.app"
EXECUTABLE_NAME="${PRODUCT_NAME}"

IORTCW_VERSION=$(grep '^VERSION=' Makefile | sed -e 's/.*=\(.*\)/\1/')

BUILT_PRODUCTS_DIR="${OBJROOT}/${TARGET_NAME}-darwin-${CURRENT_ARCH}"

APP_BUNDLE="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "**** ERROR: ${APP_BUNDLE} not found."
    echo "Run ./make-macosx-app.sh ${TARGET_NAME} ${CURRENT_ARCH} first."
    exit 1
fi

echo "Found bundle: ${APP_BUNDLE}"
echo "Version: ${IORTCW_VERSION}"

DMG_NAME="${PRODUCT_NAME}-${IORTCW_VERSION}.dmg"
DMG_FINAL="${BUILT_PRODUCTS_DIR}/${DMG_NAME}"
DMG_TEMP="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}-tmp.dmg"
VOLUME_NAME="${PRODUCT_NAME}"
MOUNT_POINT="/Volumes/${VOLUME_NAME}"

# Detach all hdiutil disk images whose path contains a given substring
detach_images_matching() {
    local pattern="$1"
    hdiutil info 2>/dev/null | grep -E "^image-path" | grep "${pattern}" | while read -r _key _colon img; do
        hdiutil detach "${img}" -force 2>/dev/null || true
    done
}

ATTACH_DEV=""

cleanup() {
    if [ -n "${ATTACH_DEV}" ]; then
        hdiutil detach "${ATTACH_DEV}" -force 2>/dev/null || true
    fi
    detach_images_matching "${BUILT_PRODUCTS_DIR}"
    rm -f "${DMG_TEMP}"
}
trap cleanup EXIT

# Eject any stale mounts from this build dir (final DMG, leftover temp DMGs)
detach_images_matching "${BUILT_PRODUCTS_DIR}"

# Calculate size: bundle size in MB + 20% headroom, minimum 128 MB
BUNDLE_SIZE_KB=$(du -sk "${APP_BUNDLE}" | awk '{print $1}')
DMG_SIZE_MB=$(( (BUNDLE_SIZE_KB / 1024) * 120 / 100 + 32 ))
if [ "${DMG_SIZE_MB}" -lt 128 ]; then
    DMG_SIZE_MB=128
fi

echo "Creating temp DMG (${DMG_SIZE_MB}m)..."
hdiutil create \
    -size "${DMG_SIZE_MB}m" \
    -fs HFS+ \
    -volname "${VOLUME_NAME}" \
    -o "${DMG_TEMP}"

echo "Mounting temp DMG..."
ATTACH_DEV=$(hdiutil attach "${DMG_TEMP}" -mountpoint "${MOUNT_POINT}" -nobrowse -noverify 2>&1 \
    | awk '/^\/dev\/disk[0-9]+[[:space:]]/ { print $1; exit }')
if [ -z "${ATTACH_DEV}" ]; then
    echo "**** ERROR: failed to attach temp DMG"
    exit 1
fi
echo "  attached as ${ATTACH_DEV}"

echo "Copying bundle..."
cp -R "${APP_BUNDLE}" "${MOUNT_POINT}/"

echo "Creating /Applications symlink..."
ln -s /Applications "${MOUNT_POINT}/Applications"

echo "Unmounting..."
sync
hdiutil detach "${ATTACH_DEV}" -quiet || hdiutil detach "${ATTACH_DEV}" -force -quiet
ATTACH_DEV=""
sleep 1

echo "Converting to compressed DMG..."
rm -f "${DMG_FINAL}"
hdiutil convert "${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_FINAL}"

echo ""
echo "Done: ${DMG_FINAL}"
