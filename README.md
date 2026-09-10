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
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android%20%7C%20Web-blue)](https://github.com/iax32/Orbit-Note/releases)

---

## 📥 Downloads

Get the latest stable build for your platform from the [**Releases**](https://github.com/iax32/Orbit-Note/releases/latest) page:

| Platform | Download Link | Notes |
| :--- | :--- | :--- |
| **🪟 Windows (x64)** | [**Download `OrbitNote-Windows-x64.zip`**](https://github.com/iax32/Orbit-Note/releases/latest) | Standalone portable folder. No installer needed. |
| **📱 Android** | [**Download `OrbitNote-Android.apk`**](https://github.com/iax32/Orbit-Note/releases/latest) | Direct APK download for Android phones/tablets. |
| **🌐 Web** | [**Run Web Build**](https://github.com/iax32/Orbit-Note/releases/latest) | Run locally or deploy as a static site. |

### 🚀 Running on Windows
1. Download [**`OrbitNote-Windows-x64.zip`**](https://github.com/iax32/Orbit-Note/releases/latest).
2. Extract the ZIP archive anywhere on your PC (e.g. `Desktop` or `Program Files`).
3. Double-click **`orbit_note.exe`** to launch!
> *Note: Keep all extracted files and the `data/` folder together in the same directory.*

### 📱 Installing on Android
1. Download [**`OrbitNote-Android.apk`**](https://github.com/iax32/Orbit-Note/releases/latest) on your Android device.
2. Tap the downloaded file to install (allow "Install unknown apps" if prompted).

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
- **Android:** Android SDK & Java Development Kit (JDK 17)

### Quick Start

```powershell
# 1. Clone the repository
git clone https://github.com/iax32/Orbit-Note.git
cd Orbit-Note

# 2. Get Flutter dependencies
flutter pub get

# 3. Run on your platform
flutter run -d windows    # Native Windows desktop
flutter run -d chrome     # Web browser
flutter run -d <device>   # Android device/emulator
```

### Production Builds

```bash
# Windows x64 release
flutter build windows --release

# Android APK release
flutter build apk --release

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
