# Installing mxCut

Download mxCut from the
[latest release](https://github.com/xnmrph/mxCut/releases/latest). FFmpeg is
included in every download.

## Windows

### With the installer (recommended)

1. Download **`mxCut-<version>-setup.exe`**.
2. Open it. If Windows shows "Windows protected your PC", click
   **More info**, then **Run anyway**. (mxCut isn't code-signed, so Windows
   doesn't recognise it yet.)
3. Follow the steps. You can also add a desktop shortcut.
4. Start mxCut from the Start menu.

To update, download the newer setup file and run it. It replaces the old
version and keeps your settings.

To uninstall, go to **Settings > Apps > Installed apps**, find **mxCut** and
click **Uninstall**.

### Without installing

1. Download **`mxCut-<version>-windows-x64.zip`**.
2. Right-click it and choose **Extract All**.
3. Open the extracted `mxCut` folder and double-click **`mxcut.exe`**.

Keep the whole folder together; `mxcut.exe` needs the files next to it.

## Linux

### AppImage

1. Download **`mxCut-<version>-x86_64.AppImage`**.
2. Make it runnable, either in your file manager (Properties > Permissions >
   "Allow executing as program") or in a terminal:

   ```sh
   chmod +x mxCut-*-x86_64.AppImage
   ```

3. Double-click it, or run `./mxCut-*-x86_64.AppImage`.

It needs a Linux from 2024 or newer, such as Ubuntu 24.04 or Fedora 40. If it
won't start, your system may also need FUSE (on Ubuntu:
`sudo apt install libfuse2t64`).

### Nix and NixOS

Run it without installing:

```sh
nix run github:xnmrph/mxCut
```

Install it for your user, with a menu entry:

```sh
nix profile install github:xnmrph/mxCut
```

On NixOS, add the flake to your configuration, apply its `overlays.default`,
and put `pkgs.mxcut` in `environment.systemPackages`.
