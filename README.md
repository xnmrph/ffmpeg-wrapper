# Video Trimmer

A fast, cross-platform desktop app for trimming videos with FFmpeg, one at a
time or in batches. Built with Qt 6 (QML) and libmpv, so it previews any file
FFmpeg can read and steps through it frame by frame.

## Status

| Step | What | State |
| --- | --- | --- |
| 1 | Single-video mode: preview, in/out scrubber, Fast and Accurate trims | Done |
| 2 | Folder mode with a sidebar and an export queue | Done |
| 3 | Output settings (folder, filename pattern, encoder options) | Done |
| 4 | Packaging: Windows installer, Nix package, AppImage | Planned |

## Using it

### One video

Open a video with **Open video…**, drag one onto the window, or pass a path on
the command line. Set the in and out points by dragging the handles on the
timeline or with the keyboard, choose a mode and click **Trim**. The result is
saved next to the original as `<name>_trim.<ext>`.

### A folder of videos

Open a folder with **Open folder…** (or drop one onto the window, or pass it on
the command line). The videos in it are listed on the left. For each one you
want, set the in and out points and press **Add to queue** (Q); the app moves
on to the next video unless you untick "Then go to next video". Queuing a
video again updates its cut. When you're ready, click **Start trimming**: each
video is trimmed into its own file, a few at a time ("At once" sets how many).
The sidebar shows which videos are queued, done or failed, and the in and out
points you set are kept while you move between videos.

| Key | Action |
| --- | --- |
| Space | Play / pause |
| I / O | Set in / out point at the playhead |
| ← / → | Step one frame back / forward |
| Shift + ← / → | Jump 5 seconds |
| [ / ] | Jump to the in / out point |
| Q | Add to queue (folder mode) |
| ↑ / ↓ | Previous / next video (folder mode) |
| Ctrl + O | Open a video |
| Ctrl + Shift + O | Open a folder |
| Ctrl + , | Settings |

### Settings

**Settings…** (top right) is saved between runs:

- **Output**: save next to the original or in one folder, and the file name
  pattern. `{name}`, `{in}`, `{out}`, `{mode}`, `{date}` and `{time}` are filled
  in; existing files get `_2`, `_3`, ... unless overwriting is on. The original
  is never overwritten.
- **Accurate mode encoding**: the video encoder (x264, x265, SVT-AV1, or NVIDIA,
  Intel, AMD and VA-API GPU encoders), quality, speed, and whether audio is
  re-encoded to AAC or copied. GPU encoders are offered only when a short test
  encode works on your machine.
- **FFmpeg**: find it automatically, or point at a specific `ffmpeg` program. A
  banner warns when no working FFmpeg is found.

When a trim fails, the message says what went wrong in plain words (unreadable
file, full disk, GPU encoder not working, ...); hover it to see FFmpeg's own
output.

**Fast** copies the streams without re-encoding. It is lossless and finishes
in seconds, but the cut starts at the keyframe at or before the in point.

**Accurate** re-encodes to H.264 and AAC so the cut lands on the exact frame.
It is slower. MKV inputs stay MKV; everything else becomes MP4.

FFmpeg is looked up in this order: the program chosen in Settings, next to the
app, then on `PATH`.

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
- `src/TrimJob.*` runs one FFmpeg trim and reports its progress.
- `src/ExportQueue.*` is folder mode's queue of TrimJobs, run a few at a time.
- `src/VideoFolderModel.*` lists the videos in a folder, in natural order, with their queue state.
- `src/Settings.*` holds the saved choices; `src/Encoders.*` maps each encoder to FFmpeg arguments, and
  `src/EncoderProbe.*` finds FFmpeg and tests which encoders work.
- `qml/Main.qml` is the window, `qml/Scrubber.qml` the timeline with the in/out handles, and
  `qml/FileSidebar.qml` and `qml/QueuePanel.qml` the folder-mode side panels, and
  `qml/SettingsDialog.qml` the Settings window.
- `tests/` holds tests for the C++ classes, which generate clips and check real FFmpeg output.

Set `VIDEO_TRIMMER_MPV_LOG=v` to print mpv's log when debugging playback.
