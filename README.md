<p align="center">
  <img src="assets/logo.png" alt="Orbit Note Logo" width="128" height="128" />
</p>

# 🪐 Orbit Note

**Your knowledge, in one system.**  
An open-source, local-first personal knowledge operating system combining linked Markdown, structured object views, spatial boards, and freeform ink. Create an object once and use it anywhere.

[![Release](https://img.shields.io/github/v/release/iax32/Orbit-Note?color=blue&label=release)](https://github.com/iax32/Orbit-Note/releases)
[![CI](https://github.com/iax32/Orbit-Note/actions/workflows/ci.yml/badge.svg)](https://github.com/iax32/Orbit-Note/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.44.8-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%201.0-blue)](https://github.com/iax32/Orbit-Note/releases)

---

## 📥 Downloads

The current **1.0.5 preview** is available on the [release page](https://github.com/iax32/Orbit-Note/releases/tag/preview-1.0.5-2026-10-28).
Older stable releases remain available in the [release archive](https://github.com/iax32/Orbit-Note/releases).

| Platform | Download Link | Notes |
| :--- | :--- | :--- |
| **🪟 Windows (x64)** | [**Download `OrbitNote-Windows-x64-Setup.exe`**](https://github.com/iax32/Orbit-Note/releases/download/preview-1.0.5-2026-10-28/OrbitNote-Windows-x64-Setup.exe) | Per-user setup EXE with the complete runtime and updated live host; no ZIP extraction or administrator account required. Unsigned. |
| **📱 Android preview** | [**Download `OrbitNote-Android-preview.apk`**](https://github.com/iax32/Orbit-Note/releases/download/preview-1.0.5-2026-10-28/OrbitNote-Android-preview.apk) | Google sign-in configured; existing preview signing key and package identity; version code 6 updates the previous preview. |

Verify downloads with the release's `SHA256SUMS.txt`. These packages support offline
core features. Windows and Android include their registered Google app clients;
Google's testing-account restrictions still apply. Android physical-device
acceptance is pending. Shared Vault now offers Start live sharing → Copy tablet invitation → Join using a reviewed temporary HTTPS relay; Advanced manual hosting remains available.
Google Drive provides file sync rather than the live ink relay.

### 🚀 Running on Windows
1. Download [**`OrbitNote-Windows-x64-Setup.exe`**](https://github.com/iax32/Orbit-Note/releases/download/preview-1.0.5-2026-10-28/OrbitNote-Windows-x64-Setup.exe).
2. Run setup to install for your Windows account.
3. Open **Orbit Note** from the Start menu, or run **`orbit_note.exe`** in the installation folder.
> Source builds still run directly from `build/windows/x64/runner/Release/orbit_note.exe`.
> Keep the EXE, DLLs and `data/` folder together. Setup does not launch the app or delete Vaults.

### 📱 Android and 🌐 Web status

Android preview uses `org.orbitnote.app.preview` and the label **Orbit Note Preview**.
Its new signing key cannot update older APKs; the separate identity preserves the
older installation. Transfer Vaults explicitly through portable backup/import.

Android and Web remain validation builds, outside the Windows 1.0 release cut.
Android device acceptance, browser persistence, and folder import still need a
production pass. Build them locally with `flutter build apk --debug` or
`flutter build web --release`.

---

## ✨ Features

- **📝 Linked Markdown Editor:** Rich Markdown with live bidirectional `[[WikiLinks]]`, task lists, visual tables, syntax-highlighted code blocks, and embedded KaTeX LaTeX math (`$math$`).
- **🎨 Spatial Infinite Canvas & Ink:** Vector ink engine, handwriting, geometric shapes, sticky notes, and smooth pan/zoom.
- **🧬 Universal Object Identity:** Placement deletion is not object deletion. Embed and transclude objects across documents, boards, and lists without duplicated copies.
- **🔒 Local-First & 100% Private:** Your files remain standard Markdown, JSON, and ordinary attachments on your disk. Native Drift/SQLite provides instant indexed search and query capability.
- **🖥️ Desktop-Class UX:** Multi-tab layout, resizable vertical/horizontal split panes, native drag-and-drop file import, full keyboard shortcuts, and clean dark mode.
- **⚡ Offline-First Core:** Operates completely offline without accounts, logins, or cloud lock-in.

---

## 🛠️ Building from Source

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) **3.44.8** (Dart **3.12.2**)
- **Windows:** Visual Studio 2022+ with the *"Desktop development with C++"* workload

### Quick Start

```powershell
# 1. Clone the repository
git clone https://github.com/iax32/Orbit-Note.git
cd Orbit-Note

# 2. Get Flutter dependencies
flutter pub get

# 3. Run on your platform
flutter run -d windows    # Native Windows desktop
flutter run -d chrome     # Web validation preview
flutter run -d <device>   # Android validation preview
```

### Production Builds

```bash
# Windows x64 release
flutter build windows --release

# Web static bundle
flutter build web --release
```

---

## 🧪 Testing & Validation

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Standard `v*` release tags run these checks in CI before packaging. The 1.0.5
preview was built and uploaded locally after focused sync tests and analysis;
no GitHub Actions workflow was dispatched. Download checksums accompany the installers. Android and Web remain
validation targets until their acceptance gates are complete.

---

## 📖 Architecture & Documentation

- [Product Definition](docs/product/product-definition.md)
- [Feature Specifications](docs/features/README.md)
- [Architecture Decision Records (ADRs)](docs/architecture/decisions/README.md)
- [Current Task & Roadmap](docs/tasks/current.md)
- [Contributing Guide](CONTRIBUTING.md)

---

## 📄 License

Orbit Note is open-source software licensed under the [MIT License](LICENSE).
