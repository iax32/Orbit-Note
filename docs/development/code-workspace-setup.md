# Code workspace

The desktop app includes a project editor for small scripts and web projects.
Open **Code workspace** from the explorer toolbar, command palette, Game dashboard
or Analysis dashboard, then choose a source folder. The existing attachment editor
and read-only source browser remain available. Native project tools are unavailable
on web/mobile; ordinary code notes and attachments remain compatible.

## Editing

- Open multiple source files in tabs; create files and folders by relative path.
- HTML, Python and C++ have syntax highlighting and offline completion snippets.
  Existing JavaScript, CSS, shader and other supported source extensions can also
  be edited; semantic tool integration currently covers HTML/Python/C++.
- Each tab retains its own caret, undo/redo and unsaved draft. Use Code actions for
  find/replace, go to line, comments, indentation, duplicate/move/delete lines,
  completion, saved checkpoints and comparison with external changes.
- Search project files uses the shared bounded source search. Changed drafts or
  files do not receive an outdated exact-line selection.
- **Capture evidence note** copies an explicit selected line range into an ordinary
  Vault note, retaining path, excerpt/source hashes and the dashboard object link.
  Editing source files does not silently create Vault objects.

| Shortcut | Action |
|---|---|
| Ctrl/Cmd+S | Save active source |
| Ctrl/Cmd+Shift+S | Save all open sources; report any partial failure |
| Ctrl/Cmd+W | Close tab while retaining its draft |
| Ctrl/Cmd+F / H | Find / replace |
| Ctrl/Cmd+G | Go to line |
| Ctrl/Cmd+Space | Completion |
| F12 | Definition via connected language server |
| F5 | Console debug Python/C++ |
| Ctrl+F5 | Run Python/C++; preview HTML |

Files are UTF-8, at most 1 MiB, with up to 20 open tabs. Byte-order marks and
authored line endings are retained. Existing source scans have explicit file,
entry, depth and generated-directory limits. Large/unsupported highlighting uses
the existing plain-text fallback. Folder access is scoped to the selected root;
symlink escapes, binary files and traversal paths are rejected.

## Local language tools

Syntax, snippets and editing work offline without a server. For semantic
completion, diagnostics, hover, definitions, symbols and formatting, select
**Local tools**, enter installed executable paths and JSON argument arrays, then
**Save local tools**. Choose **Language → Connect** explicitly for the active
language. Preferences are private to this device and are outside Vault exports.

Examples, with paths adjusted to your installed tools:

| Language | Executable | Arguments (JSON) |
|---|---|---|
| Python | Python interpreter containing python-lsp-server | `["-I", "-m", "pylsp"]` |
| HTML | `node.exe` / Node executable | `["/absolute/path/to/vscode-html-language-server", "--stdio"]` |
| C++ | `clangd.exe` / clangd executable | `["--background-index=false"]` |

Python tooling is provided by [python-lsp-server](https://github.com/python-lsp/python-lsp-server).
The Node HTML server is available in
[vscode-langservers-extracted](https://github.com/hrsh7th/vscode-langservers-extracted).
C++ semantics use [clangd](https://clangd.llvm.org/installation); real projects may
need `compile_commands.json`. Install tools separately; Orbit does not bundle or
automatically install them. On Windows, `.cmd`/`.bat` wrappers are refused: use the
actual executable plus module/script arguments. Python `-I` isolates tooling from
project-local Python modules and user-site packages; select the environment where
the language server was installed.

The [LSP adapter](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/)
uses UTF-16 positions and versioned document updates. Formatting shows a preview
before applying; results arriving after a newer edit are refused. Server-initiated
edits and commands are disabled. Unversioned diagnostics are visibly unverified
and cannot jump to a potentially wrong location. A failed server leaves offline
editing usable and can be reconnected.

## Run, check and debug

Nothing executes on open. Save first; Orbit rechecks source hashes and document
context before starting a tool. Commands use separate executable/argument values,
never a project command string evaluated by a shell.

- **Python check:** parse syntax without executing the script. **Run Python:** run
  the saved file in the selected project root. **Debug in console:** Python's
  `pdb`; enter commands such as `b 12`, `n`, `s`, `c`, `p expression` or `q`.
- **C++:** build one `.cpp`/`.cc`/`.cxx`/`.c` file using C++20 and debug information,
  then optionally run it. Installed clang++, g++ or Windows MSVC are supported.
  Headers are edited beside the source, not built as programs. MSVC receives local
  toolchain/SDK environment values only for the child process. Configure a matching
  GDB/LLDB/CDB executable and JSON argument array for console debugging; `{program}`
  expands to the built executable. For GDB the default is `["--args", "{program}"]`.
- **HTML preview:** open the saved file in the system browser. This is file preview,
  not a development server; browser restrictions for modules/network resources
  still apply. Opening a web page can run its authored JavaScript.
- Output is bounded to 40,000 visible UTF-16 units and plain text. Input is sent
  through the console field. **Stop** terminates the owned process (and its tree on
  Windows). Closing/changing project also stops the owned process.

These include useful single-file workflows. Saved profiles and local web preview
are described below. Environment/package management, bundler integration,
workspace-wide refactoring and graphical
debug-adapter breakpoints/watch panels remain future work. Python and HTML semantic
tools and installed MSVC compilation have real temporary-project acceptance;
clangd and third-party C++ console debuggers require separate device acceptance.

## Recovery and source ownership

Normal UTF-8 files are authoritative. Save checks the expected SHA-256, serializes
Orbit saves with a project lock, flushes a before/after checkpoint, then replaces
the file from a same-directory temporary file. A stale/locked/failed replacement
retains the source and checkpoint. Checkpoints can include attempted saves; they
are not a claim that every proposal was committed. Compare external changes and
review the chosen text before retrying; the final save checks the source again.

`.orbit-ide/drafts` stores versioned per-session recovery files after a short typing
delay. A save clears only this session's draft; other session drafts remain intact
and may need review against the current source. `.orbit-ide/history` retains save
checkpoints (the picker shows the latest 50); `.orbit-ide/build` contains generated
programs/debug artifacts. Add `.orbit-ide/` to the project's ignore file if desired.
No automatic cleanup discards another session's draft or history. Future/malformed
recovery data remains intact and current source opens with a warning. Recovery
failure prevents a normal close from silently discarding the in-memory edit.

External tools that ignore Orbit's lock can still race file replacement; expected
hash checks and retained checkpoints reduce that risk, not a hardware power-loss
guarantee. Save All is per-file, not an atomic project transaction. Retain ordinary
project backups; source projects are not included automatically in Vault backups.

## Saved run and build profiles

Choose **Run profiles** to add Python, C++ build/run or custom executable presets.
Edit the name, project-relative working folder (`.` means the root), tool and JSON
argument array for each step. Up to 30 profiles and eight ordered steps are
supported. Choose the profile in the Code workspace and press **Run profile**.
Opening a project or selecting a profile never executes it.

Arguments retain spaces and punctuation as literal values. `{output}` expands to
the profile's generated executable; `{buildDir}` expands to its output directory.
Python/compiler steps use this device's Local tools settings; custom steps specify
an installed executable. A Built program step runs `{output}`. No `.cmd`/`.bat`
wrapper or shell command string is evaluated. For Node/npm-style tasks, use the
actual Node executable and a script path/argument array. Tools are not installed
automatically.

For a basic two-file MSVC project, append `helper.cpp` to the preset's compiler
arguments; `/Fo:{buildDir}/` writes separate object files. GCC/Clang profiles can
also list multiple source files. A custom executable step can invoke an installed
build tool; Orbit does not discover or configure CMake/other build systems for you.
Build artifacts are not isolated transactions across separate app instances.

Source drafts must be saved first. Open source hashes/versions and the saved
profile configuration are checked; a failed/cancelled step prevents later steps.
**Stop** also handles cancellation while a process is still starting. Output and
input use the shared console. Editing profiles preserves unknown fields and uses
hash-checked saves/checkpoints. Delete retains history; **Restore checkpoint** can
recover earlier settings. Conflicts require Reload instead of overwriting another
session's changes. This is project-local `.orbit-ide` data, outside Vault backups.

## Local web development preview

Open an HTML file and press **Start web preview** after saving web source drafts.
Orbit starts an ephemeral loopback HTTP server and opens its address in the system
browser. Root-relative/relative CSS, JavaScript modules, images and fonts are served
from the selected project. Ordinary web assets, JSON, WebAssembly and supported
audio/video/PDF files are streamed, up to 64 MiB per asset; directories are not
listed and hidden files/source scripts are refused.

Orbit saves and Refresh preview request browser reload. Native supported-file
watching also notices external saves where the OS supports it; unavailable watching
reports a limitation. HTML receives a small polling/reload script (up to 2 MiB).
Authored CSP can block that script, in which case use the browser's reload command.
Reload resets unsaved page/form state. This is static preview, not a bundler,
backend router, public sharing link, TypeScript compiler or full media Range server.

**Copy preview address**, **Refresh preview** and **Stop preview** are available
while it runs. Changing projects, closing the Code workspace or successfully
exiting the app stops the service. Each preview has independent authorization,
so multiple running previews can share a browser without cookie interference.
The address/token is temporary, private and not saved in project/Vault settings.
Web/mobile builds show the existing desktop capability boundary.
