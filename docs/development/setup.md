# Development setup and validation

## Configured Windows release

Use `./tool/build_windows.ps1 -Flutter 'C:/path/to/flutter/bin/flutter.bat'` to retain
ignored local Google registration when rebuilding. It validates the platform
configuration before compilation; `-LocalOnly` explicitly omits it. See
[Google activation](google-drive-activation.md) for current scope and limits.

## Post-reset Windows toolchain — 2026-09-16

The active Desktop checkout uses pinned Flutter 3.44.8 / Dart 3.12.2 restored to
its ignored `.local/toolchain/flutter` directory. Dot-source the ignored
`.local/flutter-env.ps1` to select the SDK's short path and project-local Pub cache;
native hooks otherwise fail on the workspace path's spaces. Package versions were
not upgraded. Project-local Windows plugin junctions are used as described below.

With owner approval, Visual Studio Build Tools 2022 17.14.41 and Windows SDK
10.0.26100.0 were installed using the C++ build tools workload and recommended
components. Also install `Microsoft.VisualStudio.Component.VC.ATL`: the existing
Windows secure-storage plugin requires `atlstr.h`, which the workload alone did
not supply. The Windows release build and five-second responding startup check
passed. Current evidence and remaining acceptance limits are in
[the current task](../tasks/current.md). Android SDK/Chrome were not restored in
this Windows build task.

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

## Windows preview setup packaging — 2026-10-20

The separately dispatched `windows-preview.yml` workflow builds the configured
desktop app and standalone server, then uses the runner's existing Inno Setup 6
compiler with `tool/package_windows.ps1`. Set the distributor desktop client ID
repository variable and native-client secret using the existing encrypted secret
boundary. No user account tokens or local Vaults enter source or release assets.
The output is `OrbitNote-Windows-x64-Setup.exe`, plus checksums and a runtime
manifest tied to the workflow's source commit. Setup installs per user under
LocalAppData/Programs, adds a Start-menu shortcut and does not launch the app,
register autostart or remove user Vaults. It is unsigned. The complete runtime
folder remains directly runnable for local builds.

For a local compiler already installed, run:

```powershell
./tool/package_windows.ps1 -Compiler 'C:/path/to/ISCC.exe' -SourceCommit (git rev-parse HEAD)
```

## Android release signing (post-1.0 track)

Android is currently a validation target and is outside the Windows 1.0 release
workflow. Local Android release builds may use the development debug key. Before
publishing an Android artifact, restore a dedicated release job with these
repository secrets: `ORBIT_ANDROID_KEYSTORE_BASE64`,
`ORBIT_ANDROID_STORE_PASSWORD`, `ORBIT_ANDROID_KEY_ALIAS`, and
`ORBIT_ANDROID_KEY_PASSWORD`. The decoded keystore must remain ephemeral and
`android/key.properties` must never be committed.

The separately dispatched `android-preview.yml` workflow builds a release-mode
preview with a dedicated persistent preview key. It requires encrypted repository
secrets `ORBIT_ANDROID_PREVIEW_KEYSTORE_BASE64` and
`ORBIT_ANDROID_PREVIEW_STORE_PASSWORD`; no private signing material enters Git or
artifacts. It verifies the APK signature and records package metadata/checksums.
The owner authorized a new key after the reset; it cannot update earlier APKs
signed with the lost key. The preview workflow sets `ORBIT_ANDROID_PREVIEW=true`,
using `org.orbitnote.app.preview` and the label Orbit Note Preview so it installs
beside the older app without replacing its private data. Default builds retain
`org.orbitnote.app` and the Orbit Note label. Android device acceptance remains
unperformed.

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
