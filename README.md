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

The current **1.0.0 preview** is available on the [release page](https://github.com/iax32/Orbit-Note/releases/tag/v1.0.0%2B1).
Older stable releases remain available in the [release archive](https://github.com/iax32/Orbit-Note/releases).

| Platform | Download Link | Notes |
| :--- | :--- | :--- |
| **🪟 Windows (x64)** | [**Download `OrbitNote-Windows-x64.zip`**](https://github.com/iax32/Orbit-Note/releases/download/v1.0.0%2B1/OrbitNote-Windows-x64.zip) | Standalone portable folder. Unsigned; no installer needed. |
| **📱 Android preview** | [**Download `OrbitNote-Android-Preview.apk`**](https://github.com/iax32/Orbit-Note/releases/download/v1.0.0%2B1/OrbitNote-Android-Preview.apk) | Release-mode APK, dedicated preview signing key; installs alongside older Orbit Note installations. |

Verify downloads with the release's `SHA256SUMS.txt`. These packages support offline
core features; Google sign-in is unconfigured until distributor OAuth registration
is completed. Android device acceptance is still pending.

### 🚀 Running on Windows
1. Download [**`OrbitNote-Windows-x64.zip`**](https://github.com/iax32/Orbit-Note/releases/download/v1.0.0%2B1/OrbitNote-Windows-x64.zip).
2. Extract the ZIP archive anywhere on your PC (e.g. `Desktop` or `Program Files`).
3. Double-click **`orbit_note.exe`** to launch!
> *Note: Keep all extracted files and the `data/` folder together in the same directory.*

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

Tagged releases run the same checks in CI before packaging, then publish the
Windows artifact with a `SHA256SUMS` manifest. Android and Web remain validation
targets until their acceptance gates are complete.

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
