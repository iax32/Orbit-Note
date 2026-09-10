# Development setup and validation

Bootstrap date: 2026-09-07. Baseline: Flutter **3.44.8 stable**, Dart **3.12.2**.
The app contains only Flutter runtime, Flutter test SDK and `flutter_lints`.
Riverpod is introduced by M0-01; Drift starts with actual persistence work.

## Environment

Install this baseline Flutter SDK and put its `bin` directory on PATH. Flutter
includes Dart. Windows needs Visual Studio's Desktop development with C++ workload,
not merely the Visual Studio Code editor. Confirm setup with `flutter doctor -v`.
See [Flutter Windows setup](https://docs.flutter.dev/platform-integration/windows/setup).

On the bootstrap machine Flutter was available in an existing SDK but absent from
PATH. An ignored `.local/flutter-env.ps1` file is supplied in the original checkout.
If present, dot-source it in PowerShell for that session:

```powershell
. .\.local\flutter-env.ps1
```

It adds the existing Flutter SDK to the current session's PATH and selects the
installed Windows SDK 10.0.26100.0 for this session. It does not install/upgrade tools
or change machine-wide settings. Fresh clones should use their own SDK installation.
Do not commit machine-specific SDK paths.

The bootstrap machine's Windows SDK 10.0.28000.0 `mt.exe` exited with 0xC0000135
before processing its input and caused LNK1327 during linking. Selecting the
already-installed 10.0.26100.0 SDK resolved the build. The Windows runner conditionally
enables CMake policy CMP0149 before `project()` so a developer's `WindowsSDKVersion`
environment selection is honored. Other machines retain their normal SDK selection.
See [CMake's SDK selection rules](https://cmake.org/cmake/help/latest/variable/CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION.html).

## Standard checks

Run from the repository root:

```text
flutter pub get
dart format lib test
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build windows --debug
flutter build web
```

Use `flutter run -d windows` for manual desktop interaction. `flutter run -d chrome`
uses an installed browser. Android uses `flutter run -d <device-id>` after SDK/device
setup. iOS must be compiled/tested on macOS with Xcode; Windows cannot validate it.

Commit `pubspec.lock`. Keep `.dart_tool`, build outputs, SDK/package caches,
Android `local.properties`, signing files, credentials and personal workspaces out
of Git. Do not regenerate runners over manual changes just to add a package.

## Bootstrap evidence

| Check | Result (2026-09-07) |
|---|---|
| Dependency resolution | Passed; app lockfile retained |
| Dart format and zero-change format check | Passed, two Dart files |
| Flutter analyze | Passed, no issues |
| Flutter test | Passed, one bootstrap widget test |
| Windows debug build | Passed in the requested Desktop folder, using installed SDK 10.0.26100.0 |
| Web build | Passed; Flutter also reported a successful WASM dry run (not a WASM runtime test) |
| Documentation | 29 authored Markdown files, 68 local links and six ADRs verified; AGENTS.md about 2.4 KB |
| Android / iOS | Runners and identifiers prepared; platform builds/runtime tests not performed |

The web compiler emitted a non-blocking CupertinoIcons font advisory. This starter
does not use Cupertino icons; no unused icon dependency was added to suppress it.
The setup pass does not mark M0-01 complete. Build success is not a manual desktop
interaction test and does not validate signing or distribution.

## Why the documentation is split

Root `AGENTS.md` is a small navigation/rules file. Tasks link the smallest relevant
reading set, while durable decisions live in ADRs. This follows the project-scoped
instruction mechanism described in [official Codex guidance](https://learn.chatgpt.com/docs/agent-configuration/agents-md).
Do not add global Codex settings, automatic all-doc ingestion, or a copied chat
transcript to the project merely to make context available.

## Current native build notes — 2026-09-09

The application now includes native SQLite hooks and desktop plugins. On this host,
the Flutter SDK's long path contains spaces; native hook compilation succeeded via
the equivalent 8.3 SDK path. The ignored `.local/flutter-env.ps1` selects that path
and SDK 10.0.26100.0. This is host configuration, not a path to copy to other machines.
Prefer a Flutter SDK installation in a path without spaces on a new machine.

Flutter commands need write access to the SDK/cache. Desktop plugin links initially
required symlink privileges here; project-local junctions to resolved package
folders were used in `windows/flutter/ephemeral/.plugin_symlinks`. No global
Windows security setting was changed. Regeneration after changing dependencies
may require recreating these ephemeral links or enabling normal symlink support.

Current check results supersede the historical bootstrap table above; see
[implementation status](../planning/implementation-status.md). A successful web
build does not establish production durability for the browser storage adapter.
