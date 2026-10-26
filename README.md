# MirrorDesk

**Your Android phone, on your Mac.** A native macOS app that mirrors and controls an Android phone over Wi-Fi or USB — including Samsung DeX desktop mode on a virtual display. No cloud account, no companion app, no terminal.

Powered by [scrcpy](https://github.com/Genymobile/scrcpy) (Apache 2.0), bundled inside the app.

<img src="docs/icon.png" width="128" alt="MirrorDesk icon">

## Features

- **Wireless or USB** — ADB over the local network, Tailscale, or a cable.
- **Two modes** — the phone screen (portrait), or a **DeX desktop** on a virtual display (taskbar, windows, all apps) on One UI 8+.
- **Mac keyboard & mouse** — click to tap, scroll, drag; a floating toolbar with Back / Home / Recents / All apps follows the mirror window.
- **Audio** — phone audio plays through the Mac (Android 11+).
- **Clipboard** — text syncs both ways; drag files/APKs onto the window to push them; pull files back with ⌘D.
- **Notifications** — phone notifications appear in macOS Notification Center while connected.
- **Touch ID gate** — authenticate with Touch ID or your login password before mirroring.
- **Self-contained** — scrcpy and adb are bundled; no Homebrew, no terminal, no account.

## Requirements

- Apple Silicon Mac, macOS 13 or later.
- Android 11+ phone with **Wireless debugging** enabled (Developer options).
- Phone and Mac on the same Wi-Fi network, or both on Tailscale.

## Install

1. Download `MirrorDesk-1.0.zip` from Releases and unzip it.
2. Drag `MirrorDesk.app` to `/Applications`.
3. **First launch: right-click → Open.** The app is ad-hoc signed and not notarized. If macOS says it is damaged:
   ```sh
   xattr -dr com.apple.quarantine /Applications/MirrorDesk.app
   ```
4. Allow **Local Network** and **Notifications** when macOS asks.

## First connection

1. On the phone: **Settings → Developer options → Wireless debugging → Pair device with pairing code**. Note the IP:PORT and the 6-digit code.
2. In MirrorDesk: **Mirror → Pair phone… (⌘P)**, enter the pairing IP:PORT and the code.
3. Then choose **Mirror → DeX desktop (⌘2)** or **Phone screen (⌘1)**.

If discovery fails, use **Mirror → Connect to address… (⌘L)** with the IP:PORT shown on the Wireless debugging page.

## Toolbar and shortcuts

- Toolbar: Back, Home, Recents, All apps (DeX), mode switch.
- `⌘1` phone screen · `⌘2` DeX desktop · `⌘3` DeX wallpaper picker · `⌘4` all apps
- `⌘P` pair · `⌘L` connect to address · `⌘D` pull a file · `⌘.` stop
- Inside the mirror window: `⌥H` home · `⌥B` back · `⌥S` recents · `⌥F` fullscreen · `⌥O` screen off
- Right-click = Back, middle-click = Home.

## Limitations

- DeX on a virtual display has **no wallpaper** — Android binds the wallpaper to the main display only.
- DRM / `FLAG_SECURE` apps (Netflix, password managers, Secure Folder) mirror as black.
- Notifications are polled every 3 s while connected (not push); no Live Activities, Spotlight integration, or widgets.
- DeX on a virtual display is undocumented Samsung behavior and may break with One UI updates.
- Apple Silicon only (the bundled scrcpy is arm64).
- Requires enabling Developer options / Wireless debugging, which grants ADB full control of the phone — only pair Macs you trust.

## Build from source

```sh
./build.sh
```

Requires Xcode command line tools. The script downloads the official scrcpy macOS arm64 release, verifies its published SHA-256, compiles the Swift app, generates the icon, and ad-hoc signs the bundle.

## License

Apache License 2.0. See `LICENSE` and `NOTICE`. scrcpy and adb are Apache 2.0 — see `THIRD_PARTY_NOTICES.md`.

## Disclaimer

MirrorDesk is an independent project. It is not affiliated with, endorsed by, or sponsored by Samsung, Google, Apple, Genymobile, or the scrcpy maintainers. Android is a trademark of Google LLC. macOS is a trademark of Apple Inc. Samsung and DeX are trademarks of Samsung Electronics.

## 中文快速开始

1. 下载 Releases 里的 `MirrorDesk-1.0.zip`，解压后把 `MirrorDesk.app` 拖进「应用程序」。
2. 首次打开：右键 → 打开（应用未公证）。若提示「已损坏」：
   ```sh
   xattr -dr com.apple.quarantine /Applications/MirrorDesk.app
   ```
3. 手机打开「开发者选项 → 无线调试」，在 App 里 **Mirror → Pair phone…（⌘P）** 输入配对页的 IP:端口和 6 位码。
4. `⌘2` 进 DeX 桌面，`⌘1` 投手机屏幕。工具条上有返回 / 主屏 / 最近任务 / 所有应用 / 模式切换。
