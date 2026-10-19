# Video Trimmer

A fast, cross-platform desktop app for trimming videos with FFmpeg, one at a
time or in batches. Built with Qt 6 (QML) and libmpv, so it previews any file
FFmpeg can read and steps through it frame by frame.

## Status

| Step | What | State |
| --- | --- | --- |
| 1 | Single-video mode: preview, in/out scrubber, Fast and Accurate trims | Done |
| 2 | Folder mode with a sidebar and an export queue | Planned |
| 3 | Output settings (folder, filename pattern, encoder options) | Planned |
| 4 | Packaging: Windows installer, Nix package, AppImage | Planned |

## Using it

Open a video with **Open video…**, drag one onto the window, or pass a path on
the command line. Set the in and out points by dragging the handles on the
timeline or with the keyboard, choose a mode and click **Trim**. The result is
saved next to the original as `<name>_trim.<ext>`.

| Key | Action |
| --- | --- |
| Space | Play / pause |
| I / O | Set in / out point at the playhead |
| ← / → | Step one frame back / forward |
| Shift + ← / → | Jump 5 seconds |
| [ / ] | Jump to the in / out point |
| Ctrl + O | Open a video |

**Fast** copies the streams without re-encoding. It is lossless and finishes
in seconds, but the cut starts at the keyframe at or before the in point.

**Accurate** re-encodes to H.264 and AAC so the cut lands on the exact frame.
It is slower. MKV inputs stay MKV; everything else becomes MP4.

FFmpeg is looked up next to the app first, then on `PATH`.

## Building

### Linux (Debian / Ubuntu)

```sh
sudo apt install cmake pkg-config ffmpeg libmpv-dev qt6-base-dev qt6-declarative-dev \
  qml6-module-qtquick-controls qml6-module-qtquick-dialogs qml6-module-qtquick-layouts \
  qml6-module-qtquick-window qml6-module-qtqml-workerscript
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
ctest --test-dir build --output-on-failure
./build/video-trimmer
```

### Nix

```sh
nix run github:xnmrph/ffmpeg-wrapper   # run it
nix develop                            # shell with every build dependency
```

### Windows (MSYS2 UCRT64)

```sh
pacman -S mingw-w64-ucrt-x86_64-{toolchain,cmake,ninja,pkgconf,qt6-base,qt6-declarative,mpv,ffmpeg}
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/video-trimmer.exe
```

## Layout

- `src/MpvItem.*` is the video preview, a Qt Quick item drawn by libmpv's OpenGL render API.
- `src/TrimJob.*` runs one FFmpeg trim and reports its progress. Folder mode will queue these.
- `qml/Main.qml` is the window, and `qml/Scrubber.qml` is the timeline with the in/out handles.
- `tests/` holds the TrimJob tests, which generate a clip and check real FFmpeg output.

Set `VIDEO_TRIMMER_MPV_LOG=v` to print mpv's log when debugging playback.
