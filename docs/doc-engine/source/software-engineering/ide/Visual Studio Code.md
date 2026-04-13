# Visual Studio Code

VS Code is a lightweight, extensible code editor widely used for development across Windows, macOS, and Linux.

## Installation

### Fedora (Recommended for this dotfiles setup)

VS Code is installed via the official Microsoft Fedora repository as part of `install-fedora.sh` Phase 1:

```bash
bash install-fedora.sh
```

**Manual installation or version pinning:**

The separate dev tools script `install-fedora-dev.sh` manages VS Code with optional version pinning:

```bash
# Install latest VS Code
bash install-fedora-dev.sh

# Pin to a specific version (e.g., 1.115) and lock against updates
VSCODE_VERSION=1.115 bash install-fedora-dev.sh

# Upgrade to a new pinned version after testing
VSCODE_VERSION=1.116 bash install-fedora-dev.sh
```

When a version is pinned, `dnf versionlock` prevents automatic system upgrades from updating VS Code. This allows staged rollout testing before upgrading.

**To remove a version lock:**

```bash
sudo dnf versionlock delete code
```

**Installation details:**
- Microsoft GPG key is imported automatically for package verification
- Official Fedora repository: `https://packages.microsoft.com/yumrepos/vscode`
- Supports both stable `code` and `code-insiders` packages

### Ubuntu/Debian (Legacy reference)

Previous installations used snap, which encountered stability issues with certain versions:

```bash
sudo snap install --classic code
```

**Issue (1.90+):** VS Code 1.90 commonly crashed on startup on Ubuntu/snap.

**Solution:** Uninstall snap version and use the official deb package:

```bash
snap remove code
wget https://update.code.visualstudio.com/latest/linux-deb-x64/stable -O ./code.deb
sudo dpkg -i ./code.deb
```

For Ubuntu 22.04+ with apt, prefer the Microsoft repository over snap for stability.

## Documentation & Configuration

### Official VS Code Documentation

- [VS Code Settings Guide](https://code.visualstudio.com/docs/getstarted/settings)
- [Linux Setup](https://code.visualstudio.com/docs/setup/linux)
- [C/C++ Development](https://code.visualstudio.com/docs/cpp/cpp-ide)

### Extensions

VS Code extensions are installed through `File > Preferences > Extensions`. The editor suggests appropriate extensions based on the file types in your workspace.

**Recommended for this dotfiles setup:**

- **C/C++ Tools** (`ms-vscode.cpptools-extension-pack`)
  - Official Microsoft C/C++ extension pack
  - [Marketplace](https://marketplace.visualstudio.com/items?itemName=ms-vscode.cpptools-extension-pack)
  - [Documentation](https://code.visualstudio.com/docs/cpp/cpp-ide)

- **Code Runner** (`formulahendry.code-runner`)
  - Compile and run code directly
  - [Marketplace](https://marketplace.visualstudio.com/items?itemName=formulahendry.code-runner)
  - *Tip: Configure to run programs in terminal for interactive input*

- **Vim** (`vscodevim.vim`)
  - Full Vim keybindings
  - [GitHub](https://github.com/VSCodeVim/Vim)
  - [Marketplace](https://marketplace.visualstudio.com/items?itemName=vscodevim.vim)

## Code Formatting

VS Code uses `clang-format` as the default formatter for C/C++ projects (via the CppTools extension). Microsoft's Visual Studio style is the fallback.

### clang-format Configuration

VS Code looks for a `.clang-format` file at the root of your workspace:

```bash
$ cat .clang-format
---
BasedOnStyle: Google
NamespaceIndentation: All
ColumnLimit: 120
```

**Resources:**

- [clang-format Documentation](https://clang.llvm.org/docs/ClangFormat.html)
- [Web-based clang-format Configurator](https://zed0.co.uk/clang-format-configurator/) – generates `.clang-format` files interactively

**Common customizations (based on Google style):**

- `NamespaceIndentation`: `All` (indents code inside namespaces)
- `ColumnLimit`: `120` (limits lines to 120 characters instead of unlimited)

## C/C++ Development Workflow

### Setup (Linux)

Follow the [VS Code Linux C/C++ Setup Guide](https://code.visualstudio.com/docs/cpp/config-linux) to configure your workspace.

### Build Configuration (tasks.json)

The `.vscode/tasks.json` file defines build tasks such as compiling with GCC:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "C/C++: gcc build active file",
      "type": "shell",
      "command": "/usr/bin/gcc",
      "args": [
        "-g",
        "${fileDirname}/${fileBasenameNoExtension}.c",
        "-o",
        "${fileDirname}/${fileBasenameNoExtension}"
      ]
    }
  ]
}
```

**Trigger:** Press `Shift + Ctrl + B` to run the default build task.

### Debug Configuration (launch.json)

The `.vscode/launch.json` file configures debugging sessions. Create an initial configuration via `Run > Add Configuration > C/C++ (gdb)`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "(gdb) Launch",
      "type": "cppdbg",
      "request": "launch",
      "program": "${fileDirname}/${fileBasenameNoExtension}",
      "args": [],
      "stopAtEntry": false,
      "cwd": "${workspaceFolder}",
      "environment": [],
      "externalConsole": false,
      "MIMode": "gdb",
      "setupCommands": [
        {
          "description": "Enable pretty-printing for gdb",
          "text": "-enable-pretty-printing",
          "ignoreFailures": true
        },
        {
          "description": "Set disassembly flavor to Intel",
          "text": "-gdb-set disassembly-flavor intel",
          "ignoreFailures": true
        }
      ],
      "preLaunchTask": "C/C++: gcc build active file",
      "miDebuggerPath": "/usr/bin/gdb"
    }
  ]
}
```

**Trigger:** Press `F5` or select `Run > Start Debugging`.

## Vim Keybindings

Install the [Vim extension](https://marketplace.visualstudio.com/items?itemName=vscodevim.vim) to use Vim keybindings throughout VS Code. This extension provides full Vim modal editing within the editor.

## Working with Large Projects

For workspaces with many files, VS Code's file watcher may hit system limits (ENOSPC error). See the [VS Code documentation](https://code.visualstudio.com/docs/setup/linux#_visual-studio-code-is-unable-to-watch-for-file-changes-in-this-large-workspace-error-enospc) for solutions to increase file watcher limits and exclude unnecessary directories.