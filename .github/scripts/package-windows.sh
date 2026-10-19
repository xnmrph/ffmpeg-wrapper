#!/usr/bin/env bash
# Builds a self-contained Windows folder from an MSYS2 UCRT64 build:
# the app, Qt (via windeployqt), libmpv, FFmpeg and every DLL they load.
set -euo pipefail

build=${1:-build}
dist=${2:-dist/video-trimmer}
prefix=$(cygpath -u "$MINGW_PREFIX")

rm -rf "$dist"
mkdir -p "$dist"
cp "$build/video-trimmer.exe" "$dist/"
cp "$prefix/bin/ffmpeg.exe" "$prefix/bin/ffprobe.exe" "$dist/"

deployqt=$(command -v windeployqt6 || command -v windeployqt)
"$deployqt" --release --no-translations --qmldir qml --qmldir packaging/qml-deploy "$dist/video-trimmer.exe"

# Copy every DLL from the MSYS2 prefix that anything in the folder links to,
# repeating until nothing new turns up.
while :; do
    added=0
    while IFS= read -r dll; do
        name=$(basename "$dll")
        if [ ! -e "$dist/$name" ]; then
            cp "$dll" "$dist/"
            added=1
        fi
    done < <(find "$dist" -iname '*.exe' -o -iname '*.dll' | xargs -d '\n' ldd 2>/dev/null \
                | awk '{print $3}' | grep -i "^$prefix/bin/" | sort -u)
    [ "$added" = 0 ] && break
done

echo "Packaged $(find "$dist" -type f | wc -l) files, $(du -sh "$dist" | cut -f1)"
