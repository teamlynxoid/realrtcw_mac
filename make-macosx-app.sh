#!/bin/bash

# Let's make the user give us a target to work with.
# architecture is assumed universal if not specified, and is optional.
# if arch is defined, it we will store the .app bundle in the target arch build directory
if [ $# == 0 ] || [ $# -gt 2 ]; then
	echo "Usage:   $0 target <arch>"
	echo "Example: $0 release x86"
	echo "Valid targets are:"
	echo " release"
	echo " debug"
	echo
	echo "Optional architectures are:"
	echo " x86"
	echo " x86_64"
	echo " ppc"
	echo " arm64"
	echo
	exit 1
fi

# validate target name
if [ "$1" == "release" ]; then
	TARGET_NAME="release"
elif [ "$1" == "debug" ]; then
	TARGET_NAME="debug"
else
	echo "Invalid target: $1"
	echo "Valid targets are:"
	echo " release"
	echo " debug"
	exit 1
fi

CURRENT_ARCH=""

# validate the architecture if it was specified
if [ "$2" != "" ]; then
	if [ "$2" == "x86" ]; then
		CURRENT_ARCH="x86"
	elif [ "$2" == "x86_64" ]; then
		CURRENT_ARCH="x86_64"
	elif [ "$2" == "ppc" ]; then
		CURRENT_ARCH="ppc"
	elif [ "$2" == "arm64" ]; then
		CURRENT_ARCH="arm64"
	else
		echo "Invalid architecture: $2"
		echo "Valid architectures are:"
		echo " x86"
		echo " x86_64"
		echo " ppc"
		echo " arm64"
		echo
		exit 1
	fi
fi

# symlinkArch() creates a symlink with the architecture suffix.
# meant for universal binaries, but also handles the way this script generates
# application bundles for a single architecture as well.
function symlinkArch()
{
    EXT="dylib"
    SEP="${3}"
    SRCFILE="${1}"
    DSTFILE="${2}${SEP}"
    DSTPATH="${4}"

    if [ ! -e "${DSTPATH}/${SRCFILE}.${EXT}" ]; then
        echo "**** ERROR: missing ${SRCFILE}.${EXT} from ${MACOS}"
        exit 1
    fi

    if [ ! -d "${DSTPATH}" ]; then
        echo "**** ERROR: path not found ${DSTPATH}"
        exit 1
    fi

    pushd "${DSTPATH}" > /dev/null

    IS32=`file "${SRCFILE}.${EXT}" | grep "i386"`
    IS64=`file "${SRCFILE}.${EXT}" | grep "x86_64"`
    ISPPC=`file "${SRCFILE}.${EXT}" | grep "ppc"`
    ISARM=`file "${SRCFILE}.${EXT}" | grep "arm64"`

    if [ "${IS32}" != "" ]; then
        if [ ! -L "${DSTFILE}i386.${EXT}" ]; then
            ln -s "${SRCFILE}.${EXT}" "${DSTFILE}i386.${EXT}"
        fi
    elif [ -L "${DSTFILE}i386.${EXT}" ]; then
        rm "${DSTFILE}i386.${EXT}"
    fi

    if [ "${IS64}" != "" ]; then
        if [ ! -L "${DSTFILE}x86_64.${EXT}" ]; then
            ln -s "${SRCFILE}.${EXT}" "${DSTFILE}x86_64.${EXT}"
        fi
    elif [ -L "${DSTFILE}x86_64.${EXT}" ]; then
        rm "${DSTFILE}x86_64.${EXT}"
    fi

    if [ "${ISPPC}" != "" ]; then
        if [ ! -L "${DSTFILE}ppc.${EXT}" ]; then
            ln -s "${SRCFILE}.${EXT}" "${DSTFILE}ppc.${EXT}"
        fi
    elif [ -L "${DSTFILE}ppc.${EXT}" ]; then
        rm "${DSTFILE}ppc.${EXT}"
    fi

    if [ "${ISARM}" != "" ]; then
        if [ ! -L "${DSTFILE}arm64.${EXT}" ]; then
            ln -s "${SRCFILE}.${EXT}" "${DSTFILE}arm64.${EXT}"
        fi
    elif [ -L "${DSTFILE}arm64.${EXT}" ]; then
        rm "${DSTFILE}arm64.${EXT}"
    fi

    popd > /dev/null
}

SEARCH_ARCHS="	\
	x86	\
	x86_64	\
	ppc	\
	arm64 \
"

HAS_LIPO=`command -v lipo`
HAS_CP=`command -v cp`

# if lipo is not available, we cannot make a universal binary, print a warning
if [ ! -x "${HAS_LIPO}" ] && [ "${CURRENT_ARCH}" == "" ]; then
	CURRENT_ARCH=`uname -m`
	if [ "${CURRENT_ARCH}" == "i386" ]; then CURRENT_ARCH="x86"; fi
	echo "$0 cannot make a universal binary, falling back to architecture ${CURRENT_ARCH}"
fi

# if the optional arch parameter is used, replace SEARCH_ARCHS to only work with one
if [ "${CURRENT_ARCH}" != "" ]; then
	SEARCH_ARCHS="${CURRENT_ARCH}"
fi

AVAILABLE_ARCHS=""

IORTCW_VERSION=`grep '^VERSION=' Makefile | sed -e 's/.*=\(.*\)/\1/'`
IORTCW_CLIENT_ARCHS=""
IORTCW_RENDERER_GL1_ARCHS=""
IORTCW_RENDERER_GL2_ARCHS=""
IORTCW_CGAME_ARCHS=""
IORTCW_GAME_ARCHS=""
IORTCW_UI_ARCHS=""

BASEDIR="main"

CGAME="cgame.sp"
GAME="qagame.sp"
UI="ui.sp"

RENDERER_OPENGL="renderer_sp_opengl1"
RENDERER_OPENGL2="renderer_sp_rend2"

CGAME_NAME="${CGAME}.dylib"
GAME_NAME="${GAME}.dylib"
UI_NAME="${UI}.dylib"

RENDERER_OPENGL1_NAME="renderer_sp_opengl1.dylib"
RENDERER_OPENGL2_NAME="renderer_sp_rend2.dylib"

ICNSDIR="misc"
ICNS="iortcw.icns"
PKGINFO="APPLIORTCW"

OBJROOT="build"
#BUILT_PRODUCTS_DIR="${OBJROOT}/${TARGET_NAME}-darwin-${CURRENT_ARCH}"
PRODUCT_NAME="RealRTCW"
WRAPPER_EXTENSION="app"
WRAPPER_NAME="${PRODUCT_NAME}.${WRAPPER_EXTENSION}"
CONTENTS_FOLDER_PATH="${WRAPPER_NAME}/Contents"
UNLOCALIZED_RESOURCES_FOLDER_PATH="${CONTENTS_FOLDER_PATH}/Resources"
EXECUTABLE_FOLDER_PATH="${CONTENTS_FOLDER_PATH}/MacOS"
EXECUTABLE_NAME="${PRODUCT_NAME}"

# loop through the architectures to build string lists for each universal binary
for ARCH in $SEARCH_ARCHS; do
	CURRENT_ARCH=${ARCH}

	if [ ${CURRENT_ARCH} == "x86" ]; then FILE_ARCH="i386"; fi
	if [ ${CURRENT_ARCH} == "x86_64" ]; then FILE_ARCH="x86_64"; fi
	if [ ${CURRENT_ARCH} == "ppc" ]; then FILE_ARCH="ppc"; fi
	if [ ${CURRENT_ARCH} == "arm64" ]; then FILE_ARCH="arm64"; fi

	BUILT_PRODUCTS_DIR="${OBJROOT}/${TARGET_NAME}-darwin-${CURRENT_ARCH}"
	# Prefer flavor-suffixed directories (nosteam/steam) added by Makefile when they contain binaries
	for FLAVOR in nosteam steam; do
		FLAVOR_DIR="${OBJROOT}/${TARGET_NAME}-darwin-${CURRENT_ARCH}-${FLAVOR}"
		if [ -e "${FLAVOR_DIR}/${EXECUTABLE_NAME}.${CURRENT_ARCH}" ]; then
			BUILT_PRODUCTS_DIR="${FLAVOR_DIR}"
			break
		fi
	done
	IORTCW_CLIENT="${EXECUTABLE_NAME}.${CURRENT_ARCH}"
	IORTCW_RENDERER_GL1="${RENDERER_OPENGL}_${FILE_ARCH}.dylib"
	IORTCW_RENDERER_GL2="${RENDERER_OPENGL2}_${FILE_ARCH}.dylib"
	IORTCW_CGAME="${CGAME}.${FILE_ARCH}.dylib"
	IORTCW_GAME="${GAME}.${FILE_ARCH}.dylib"
	IORTCW_UI="${UI}.${FILE_ARCH}.dylib"

	if [ ! -d ${BUILT_PRODUCTS_DIR} ]; then
		CURRENT_ARCH=""
		BUILT_PRODUCTS_DIR=""
		continue
	fi

	# executables
	if [ -e ${BUILT_PRODUCTS_DIR}/${IORTCW_CLIENT} ]; then
		IORTCW_CLIENT_ARCHS="${BUILT_PRODUCTS_DIR}/${IORTCW_CLIENT} ${IORTCW_CLIENT_ARCHS}"
		VALID_ARCHS="${ARCH} ${VALID_ARCHS}"
	else
		continue
	fi

	# renderers
	if [ -e ${BUILT_PRODUCTS_DIR}/${IORTCW_RENDERER_GL1} ]; then
		IORTCW_RENDERER_GL1_ARCHS="${BUILT_PRODUCTS_DIR}/${IORTCW_RENDERER_GL1} ${IORTCW_RENDERER_GL1_ARCHS}"
	fi
	if [ -e ${BUILT_PRODUCTS_DIR}/${IORTCW_RENDERER_GL2} ]; then
		IORTCW_RENDERER_GL2_ARCHS="${BUILT_PRODUCTS_DIR}/${IORTCW_RENDERER_GL2} ${IORTCW_RENDERER_GL2_ARCHS}"
	fi

	# game
	if [ -e ${BUILT_PRODUCTS_DIR}/${BASEDIR}/${IORTCW_CGAME} ]; then
		IORTCW_CGAME_ARCHS="${BUILT_PRODUCTS_DIR}/${BASEDIR}/${IORTCW_CGAME} ${IORTCW_CGAME_ARCHS}"
	fi
	if [ -e ${BUILT_PRODUCTS_DIR}/${BASEDIR}/${IORTCW_GAME} ]; then
		IORTCW_GAME_ARCHS="${BUILT_PRODUCTS_DIR}/${BASEDIR}/${IORTCW_GAME} ${IORTCW_GAME_ARCHS}"
	fi
	if [ -e ${BUILT_PRODUCTS_DIR}/${BASEDIR}/${IORTCW_UI} ]; then
		IORTCW_UI_ARCHS="${BUILT_PRODUCTS_DIR}/${BASEDIR}/${IORTCW_UI} ${IORTCW_UI_ARCHS}"
	fi

	#echo "valid arch: ${ARCH}"
done

# final preparations and checks before attempting to make the application bundle
cd `dirname $0`

if [ ! -f Makefile ]; then
	echo "$0 must be run from the iortcw build directory"
	exit 1
fi

if [ "${IORTCW_CLIENT_ARCHS}" == "" ]; then
	echo "$0: no iortcw binary architectures were found for target '${TARGET_NAME}'"
	exit 1
fi

# set the final application bundle output directory
if [ "${2}" == "" ]; then
	BUILT_PRODUCTS_DIR="${OBJROOT}/${TARGET_NAME}-darwin-universal"
	if [ ! -d ${BUILT_PRODUCTS_DIR} ]; then
		mkdir -p ${BUILT_PRODUCTS_DIR} || exit 1;
	fi
else
	BUILT_PRODUCTS_DIR="${OBJROOT}/${TARGET_NAME}-darwin-${CURRENT_ARCH}"
fi

BUNDLEBINDIR="${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"


# here we go
echo "Creating bundle '${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}'"
echo "with architectures:"
for ARCH in ${VALID_ARCHS}; do
	echo " ${ARCH}"
done
echo ""

# make the application bundle directories
if [ ! -d "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/$BASEDIR" ]; then
	mkdir -p "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/$BASEDIR" || exit 1;
fi
if [ ! -d "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}" ]; then
	mkdir -p "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}" || exit 1;
fi

# copy and generate some application bundle resources
# Copy libopenal (still bundled in repo)
cp code/libs/macosx/libopenal.dylib "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/"

# Copy SDL3 from Homebrew
SDL3_PREFIX="$(brew --prefix sdl3 2>/dev/null)"
SDL3_LIB="${SDL3_PREFIX}/lib/libSDL3.dylib"
if [ ! -f "${SDL3_LIB}" ]; then
	SDL3_LIB="$(pkg-config --variable=libdir sdl3 2>/dev/null)/libSDL3.dylib"
fi
if [ ! -f "${SDL3_LIB}" ]; then
	echo "**** ERROR: libSDL3.dylib not found. Run: brew install sdl3"
	exit 1
fi
cp -f "${SDL3_LIB}" "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/"
chmod +w "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/$(basename "${SDL3_LIB}")"

# Copy FFmpeg dylibs from Homebrew (required -- cl_cin.c hard-links them)
FFMPEG_LIBDIR="$(pkg-config --variable=libdir libavcodec 2>/dev/null)"
if [ -z "${FFMPEG_LIBDIR}" ]; then
	FFMPEG_LIBDIR="$(brew --prefix ffmpeg 2>/dev/null)/lib"
fi
for FFLIB in libavcodec libavformat libavutil libswscale libswresample; do
	FFLIB_PATH="${FFMPEG_LIBDIR}/${FFLIB}.dylib"
	if [ ! -f "${FFLIB_PATH}" ]; then
		FFLIB_PATH="$(ls "${FFMPEG_LIBDIR}/${FFLIB}".*.dylib 2>/dev/null | sort -V | tail -1)"
	fi
	if [ -f "${FFLIB_PATH}" ]; then
		cp -f "${FFLIB_PATH}" "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/"
		chmod +w "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/$(basename "${FFLIB_PATH}")"
	else
		echo "**** ERROR: ${FFLIB}.dylib not found in ${FFMPEG_LIBDIR}. Run: brew install ffmpeg"
		exit 1
	fi
done
cp ${ICNSDIR}/${ICNS} "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/$ICNS" || exit 1;
echo -n ${PKGINFO} > "${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/PkgInfo" || exit 1;

# create Info.Plist
PLIST="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>iortcw</string>
    <key>CFBundleIdentifier</key>
    <string>org.iortcw.${PRODUCT_NAME}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${PRODUCT_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${IORTCW_VERSION}</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>${IORTCW_VERSION}</string>
    <key>CGDisableCoalescedUpdates</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>${MACOSX_DEPLOYMENT_TARGET}</string>"

if [ -n "${MACOSX_DEPLOYMENT_TARGET_PPC}" ] || [ -n "${MACOSX_DEPLOYMENT_TARGET_X86}" ] || [ -n "${MACOSX_DEPLOYMENT_TARGET_X86_64}" ] || [ -n "${MACOSX_DEPLOYMENT_TARGET_ARM64}" ]; then
	PLIST="${PLIST}
    <key>LSMinimumSystemVersionByArchitecture</key>
    <dict>"

	if [ -n "${MACOSX_DEPLOYMENT_TARGET_PPC}" ]; then
	PLIST="${PLIST}
        <key>ppc</key>
        <string>${MACOSX_DEPLOYMENT_TARGET_PPC}</string>"
	fi

	if [ -n "${MACOSX_DEPLOYMENT_TARGET_X86}" ]; then
	PLIST="${PLIST}
        <key>i386</key>
        <string>${MACOSX_DEPLOYMENT_TARGET_X86}</string>"
	fi

	if [ -n "${MACOSX_DEPLOYMENT_TARGET_X86_64}" ]; then
	PLIST="${PLIST}
        <key>x86_64</key>
        <string>${MACOSX_DEPLOYMENT_TARGET_X86_64}</string>"
	fi

	if [ -n "${MACOSX_DEPLOYMENT_TARGET_ARM64}" ]; then
	PLIST="${PLIST}
        <key>arm64</key>
        <string>${MACOSX_DEPLOYMENT_TARGET_ARM64}</string>"
	fi

	PLIST="${PLIST}
    </dict>"
fi

PLIST="${PLIST}
    <key>NSHumanReadableCopyright</key>
    <string>Return to Castle Wolfenstein single player Copyright (C) 1999-2010 id Software LLC, a ZeniMax Media company.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.games</string>
</dict>
</plist>
"
echo -e "${PLIST}" > "${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Info.plist"

# action takes care of generating universal binaries if lipo is available
# otherwise, it falls back to using a simple copy, expecting the first item in
# the second parameter list to be the desired architecture
function action()
{
	COMMAND=""

	if [ -x "${HAS_LIPO}" ]; then
		COMMAND="${HAS_LIPO} -create -o"
		$HAS_LIPO -create -o "${1}" ${2} # make sure $2 is treated as a list of files
	elif [ -x ${HAS_CP} ]; then
		COMMAND="${HAS_CP}"
		SRC="${2// */}" # in case there is a list here, use only the first item
		$HAS_CP "${SRC}" "${1}"
	else
		"$0 cannot create an application bundle."
		exit 1
	fi

	#echo "${COMMAND}" "${1}" "${2}"
}

#
# the meat of universal binary creation
# destination file names do not have architecture suffix.
# action will handle merging universal binaries if supported.
# symlink appropriate architecture names for universal (fat) binary support.
#

# executables
action "${BUNDLEBINDIR}/${EXECUTABLE_NAME}"				"${IORTCW_CLIENT_ARCHS}"

# renderers
action "${BUNDLEBINDIR}/${RENDERER_OPENGL1_NAME}"		"${IORTCW_RENDERER_GL1_ARCHS}"
symlinkArch "${RENDERER_OPENGL}" "${RENDERER_OPENGL}" "_" "${BUNDLEBINDIR}"

# game
action "${BUNDLEBINDIR}/${BASEDIR}/${CGAME_NAME}"		"${IORTCW_CGAME_ARCHS}"
action "${BUNDLEBINDIR}/${BASEDIR}/${GAME_NAME}"		"${IORTCW_GAME_ARCHS}"
action "${BUNDLEBINDIR}/${BASEDIR}/${UI_NAME}"			"${IORTCW_UI_ARCHS}"
symlinkArch "${CGAME}"	"${CGAME}."	""	"${BUNDLEBINDIR}/${BASEDIR}"
symlinkArch "${GAME}"	"${GAME}."	""	"${BUNDLEBINDIR}/${BASEDIR}"
symlinkArch "${UI}"		"${UI}."		""	"${BUNDLEBINDIR}/${BASEDIR}"

# Fix embedded dylib paths so bundle is self-contained.
# $1 = binary or dylib that links against $2
# $2 = dylib already copied into BUNDLEBINDIR
fix_dylib_ref() {
	local BINARY="$1"
	local DYLIB_DEST="$2"
	local BASENAME LIB_STEM OLD_REF
	BASENAME=$(basename "${DYLIB_DEST}")
	LIB_STEM="${BASENAME%.dylib}"
	install_name_tool -id "@executable_path/${BASENAME}" "${DYLIB_DEST}" 2>/dev/null || true
	OLD_REF=$(otool -L "${BINARY}" 2>/dev/null | awk '{print $1}' | grep "${LIB_STEM}" | grep -v "@executable_path" | head -1)
	if [ -n "${OLD_REF}" ]; then
		install_name_tool -change "${OLD_REF}" "@executable_path/${BASENAME}" "${BINARY}" 2>/dev/null || true
	fi
}

# Rewrite all non-system, non-bundled refs in BINARY to @executable_path/basename.
# Copies each referenced dylib into BUNDLEBINDIR if not already there.
# Iterates until no external refs remain (handles transitive deps).
bundle_transitive_deps() {
	local CHANGED=1
	while [ "${CHANGED}" = "1" ]; do
		CHANGED=0
		for SCAN in "${BUNDLEBINDIR}"/*.dylib "${BUNDLEBINDIR}/${EXECUTABLE_NAME}"; do
			[ -f "${SCAN}" ] || continue
			while IFS= read -r EXTREF; do
				[ -f "${EXTREF}" ] || continue
				DESTNAME=$(basename "${EXTREF}")
				DEST="${BUNDLEBINDIR}/${DESTNAME}"
				if [ ! -f "${DEST}" ]; then
					cp -f "${EXTREF}" "${DEST}"
					chmod +w "${DEST}"
					echo "  + bundled transitive dep: ${DESTNAME}"
					CHANGED=1
				fi
				# Rewrite this ref in every dylib and the main binary
				for TARGET in "${BUNDLEBINDIR}"/*.dylib "${BUNDLEBINDIR}/${EXECUTABLE_NAME}"; do
					[ -f "${TARGET}" ] || continue
					fix_dylib_ref "${TARGET}" "${DEST}"
				done
			done < <(otool -L "${SCAN}" 2>/dev/null | tail -n +2 | awk '{print $1}' \
			          | grep "^/opt/homebrew\|^/usr/local" \
			          | grep -v "^$(otool -D "${SCAN}" 2>/dev/null | tail -1)$")
		done
	done
}

BUNDLE_BIN="${BUNDLEBINDIR}/${EXECUTABLE_NAME}"
BUNDLE_RENDERER="${BUNDLEBINDIR}/${RENDERER_OPENGL1_NAME}"

# Fix renderer dylib identity (Makefile sets it to the build output path)
install_name_tool -id "@executable_path/${RENDERER_OPENGL1_NAME}" "${BUNDLE_RENDERER}" 2>/dev/null || true

# Fix refs to all already-bundled dylibs in every binary — covers:
#   - main binary & renderer → SDL3, FFmpeg
#   - FFmpeg dylibs → each other (inter-FFmpeg versioned refs)
# Must run before bundle_transitive_deps so inter-FFmpeg versioned names
# (e.g. libavcodec.62.dylib) are rewritten to the bundled unversioned name
# before the transitive scanner sees them.
for DYLIB in "${BUNDLEBINDIR}"/*.dylib; do
	[ -f "${DYLIB}" ] || continue
	for TARGET in "${BUNDLEBINDIR}"/*.dylib "${BUNDLE_BIN}" "${BUNDLE_RENDERER}"; do
		[ -f "${TARGET}" ] && fix_dylib_ref "${TARGET}" "${DYLIB}"
	done
done

# Bundle and rewrite all remaining transitive Homebrew deps (codec libs, openssl, etc.)
echo "Bundling transitive dependencies..."
bundle_transitive_deps

# Re-sign all dylibs and binaries with ad-hoc signature after install_name_tool modifications
echo "Re-signing bundle..."
for DYLIB in "${BUNDLEBINDIR}"/*.dylib; do
	[ -f "${DYLIB}" ] || continue
	codesign --force --sign - "${DYLIB}" 2>/dev/null || true
done
codesign --force --sign - "${BUNDLE_BIN}"      2>/dev/null || true
codesign --force --sign - "${BUNDLE_RENDERER}" 2>/dev/null || true

# Generate .dSYM bundles for LLDB source-level debugging
if command -v dsymutil >/dev/null 2>&1; then
	echo "Generating .dSYM bundles..."
	dsymutil "${BUNDLE_BIN}"      -o "${BUNDLE_BIN}.dSYM"      2>/dev/null || true
	dsymutil "${BUNDLE_RENDERER}" -o "${BUNDLE_RENDERER}.dSYM" 2>/dev/null || true
	for GAMELIB in "${BUNDLEBINDIR}/${BASEDIR}"/*.dylib; do
		[ -f "${GAMELIB}" ] || continue
		GAMELIB_BASE=$(basename "${GAMELIB}")
		dsymutil "${GAMELIB}" -o "${BUNDLEBINDIR}/${BASEDIR}/${GAMELIB_BASE}.dSYM" 2>/dev/null || true
	done
fi

# Bundle game content pk3 files if GAME_DATA_PATH is set
if [ -n "${GAME_DATA_PATH}" ]; then
	GAME_DATA_MAIN="${GAME_DATA_PATH}/main"
	if [ ! -d "${GAME_DATA_MAIN}" ]; then
		echo "**** ERROR: GAME_DATA_PATH set but ${GAME_DATA_MAIN} not found"
		exit 1
	fi
	echo "Bundling game content from ${GAME_DATA_MAIN}"
	for PK3 in "${GAME_DATA_MAIN}"/*.pk3; do
		[ -f "${PK3}" ] || continue
		cp -f "${PK3}" "${BUNDLEBINDIR}/${BASEDIR}/"
		echo "  + $(basename "${PK3}")"
	done
	for CFG in "${GAME_DATA_MAIN}"/*.cfg; do
		[ -f "${CFG}" ] || continue
		cp -f "${CFG}" "${BUNDLEBINDIR}/${BASEDIR}/"
		echo "  + $(basename "${CFG}")"
	done
fi

