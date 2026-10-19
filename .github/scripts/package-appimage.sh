#!/usr/bin/env bash
# Builds Video-Trimmer-<version>-x86_64.AppImage from a Linux build: the app,
# Qt and its QML modules, libmpv, and an FFmpeg next to the program.
# Usage: package-appimage.sh <build dir> <version> [output dir]
set -euo pipefail

build=$(realpath "${1:-build}")
version=${2:-0.0.0}
out=$(realpath -m "${3:-dist}")
src=$(realpath "$(dirname "$0")/../..")
tools=${APPIMAGE_TOOLS:-$build/appimage-tools}
appdir=$build/AppDir

mkdir -p "$tools" "$out"
fetch() {
    [ -x "$tools/$1" ] && return
    curl -fsSL --retry 3 -o "$tools/$1" "$2"
    chmod +x "$tools/$1"
}
fetch linuxdeploy https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
fetch linuxdeploy-plugin-qt https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
export PATH="$tools:$PATH"
# Runners have no FUSE, so let the tools unpack themselves instead.
export APPIMAGE_EXTRACT_AND_RUN=1

rm -rf "$appdir"
DESTDIR="$appdir" cmake --install "$build" --prefix /usr

# The app prefers an ffmpeg beside itself, so ship the system one there.
cp "$(command -v ffmpeg)" "$(command -v ffprobe)" "$appdir/usr/bin/"

export QML_SOURCES_PATHS="$src/qml:$src/packaging/qml-deploy"
export QMAKE=${QMAKE:-$(command -v qmake6 || command -v qmake)}
# Wayland and X11 both work; ship the Wayland platform too where it exists.
export EXTRA_PLATFORM_PLUGINS="libqwayland-egl.so;libqwayland-generic.so"
export LDAI_OUTPUT="$out/Video-Trimmer-$version-x86_64.AppImage"
export LINUXDEPLOY_OUTPUT_VERSION="$version"

linuxdeploy --appdir "$appdir" \
    --executable "$appdir/usr/bin/ffmpeg" \
    --executable "$appdir/usr/bin/ffprobe" \
    --desktop-file "$appdir/usr/share/applications/video-trimmer.desktop" \
    --icon-file "$appdir/usr/share/icons/hicolor/256x256/apps/video-trimmer.png" \
    --plugin qt \
    --output appimage

echo "Built $LDAI_OUTPUT ($(du -h "$LDAI_OUTPUT" | cut -f1))"
