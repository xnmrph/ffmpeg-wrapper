<p align="center"><img src="packaging/branding/banner.png" alt="mx" width="100%"></p>

# mxCut

A fast, cross-platform desktop app for trimming videos with FFmpeg, one at a
time or in batches. Built with Qt 6 (QML) and libmpv, so it previews any file
FFmpeg can read and steps through it frame by frame.

## Status

| Step | What | State |
| --- | --- | --- |
| 1 | Single-video mode: preview, in/out scrubber, Fast and Accurate trims | Done |
| 2 | Folder mode with a sidebar and an export queue | Done |
| 3 | Output settings (folder, filename pattern, encoder options) | Done |
| 4 | Packaging: Windows installer, Nix package, AppImage | Done |

## Installing

Tagged releases on the [Releases page](https://github.com/xnmrph/ffmpeg-wrapper/releases) carry:

- **Windows:** `mxCut-<version>-setup.exe`, an installer with a Start menu entry and an
  uninstaller, or `mxCut-<version>-windows-x64.zip` to run without installing. Both include
  FFmpeg.
- **Linux:** `mxCut-<version>-x86_64.AppImage`. Make it executable and run it; FFmpeg is
  inside. It's built on Ubuntu 24.04, so it needs a distro at least that new (glibc 2.39).
- **Nix / NixOS:** `nix run github:xnmrph/ffmpeg-wrapper`, or `nix profile install
  github:xnmrph/ffmpeg-wrapper` to keep it with its menu entry. On NixOS, add the flake's
  `overlays.default` and put `pkgs.video-trimmer` in `environment.systemPackages`.

Every CI run also uploads these as build artifacts, so builds from a pull request can be tried
before a release.

To release, bump the version in `CMakeLists.txt` and `flake.nix`, then push a tag such as `v0.2.0`, or run the Build workflow from the Actions tab with "release" ticked.

## Using it

### One video

Open a video with **Open video…**, drag one onto the window, or pass a path on
the command line. Set the in and out points by dragging the handles on the
timeline by their `<` and `>` tabs on the ruler, or with the keyboard; click or
drag anywhere else on the timeline to scrub. Choose a mode and click **Trim**.
The result is saved next to the original as `<name>_trim.<ext>`, or takes the
original's place when "Replace the original video" is on in Settings.

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
| A / D | Set in / out point at the playhead (change them in Settings) |
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
  is never overwritten, unless you tick **Replace the original video**: then the
  trimmed video takes the original's name and place and the original goes to
  the Trash or Recycle Bin. (Accurate mode may change the file type, so
  `holiday.mov` becomes `holiday.mp4`; if that name is already taken, the
  original is kept and the trim is saved as `holiday_trim.mp4`.)
- **Keyboard shortcuts**: the keys that set the in and out points.
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
  qml6-module-qtquick-window qml6-module-qtqml-workerscript qml6-module-qtquick-shapes
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

From an MSYS2 UCRT64 shell (install [MSYS2](https://www.msys2.org) first):

```sh
pacman -S mingw-w64-ucrt-x86_64-{toolchain,cmake,ninja,pkgconf,qt6-base,qt6-declarative,mpv,ffmpeg}
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/video-trimmer.exe
# Optional: a self-contained folder and an installer, as CI makes them.
pacman -S mingw-w64-ucrt-x86_64-{qt6-tools,nsis}
bash .github/scripts/package-windows.sh build dist/video-trimmer
makensis -DVERSION=0.1.0 -DDIST="$(cygpath -w "$PWD/dist/video-trimmer")" packaging/windows/installer.nsi
```

## Layout

- `src/MpvItem.*` is the video preview, a Qt Quick item drawn by libmpv's OpenGL render API.
- `src/TrimJob.*` runs one FFmpeg trim and reports its progress.
- `src/ExportQueue.*` is folder mode's queue of TrimJobs, run a few at a time.
- `src/VideoFolderModel.*` lists the videos in a folder, in natural order, with their queue state.
- `src/Settings.*` holds the saved choices; `src/Encoders.*` maps each encoder to FFmpeg arguments, and
  `src/EncoderProbe.*` finds FFmpeg and tests which encoders work.
- `src/MediaPreview.*` makes the timeline's thumbnails and waveform with FFmpeg and caches them;
  `src/WaveformView.*` draws the waveform.
- `qml/Main.qml` is the window, `qml/Timeline.qml` the ruler, thumbnail and audio tracks with the
  in/out handles, `qml/FileSidebar.qml` and `qml/QueuePanel.qml` the folder-mode side panels, and
  `qml/SettingsDialog.qml` the Settings window. `qml/Theme.qml` holds the colours and
  `qml/Icons.qml` the icon shapes.
- `packaging/` has the icon, the Linux menu entry and the Windows installer script;
  `.github/scripts/` builds the Windows folder and the AppImage.
- `tests/` holds tests for the C++ classes, which generate clips and check real FFmpeg output.

Set `VIDEO_TRIMMER_MPV_LOG=v` to print mpv's log when debugging playback.
