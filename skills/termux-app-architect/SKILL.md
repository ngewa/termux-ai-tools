---
name: termux-app-architect
description: Comprehensive architect & engineering guide for building new Android/Termux projects from scratch, maintaining and updating existing Termux projects (freebuff-termux, openclaude-termux, termux-ai-tools), and orchestrating global AI Agent skills and personas across Antigravity CLI (agy) and OpenCode (v1 & v2). Use whenever designing Termux software, creating one-liner installers, fixing glibc/bionic linkers, patching upstream packages, or syncing cross-platform agents.
---

# Termux App Architect & Ecosystem Engineer

Comprehensive engineering manual for building, maintaining, updating, and scaling developer tools, CLI applications, runtime patches, and AI agent extensions on **Android / Termux**.

This skill encapsulates the battle-tested patterns derived from **`freebuff-termux`**, **`openclaude-termux`**, and **`termux-ai-tools`**, providing exact blueprints for:
1. **Building new production-grade Termux projects** from scratch.
2. **Maintaining, repairing, and updating** the existing Termux project triumvirate.
3. **Synchronizing global AI Agent Skills & Personas** across **Antigravity CLI (agy)** and **OpenCode (v1 & v2)**.

---

## 1. Termux & Android Architecture Fundamentals

When developing for Android/Termux, standard Linux assumptions fail. Every tool must comply with these immutable constraints:

### A. Filesystem & Path Conventions
- **Root prefix**: Termux lives in `$PREFIX` (`/data/data/com.termux/files/usr`).
- **User home**: Termux home is `$HOME` (`/data/data/com.termux/files/home`).
- **Standard Linux paths (`/usr`, `/bin`, `/etc`) DO NOT EXIST** on Android:
  - Never hardcode `#!/bin/bash` or `#!/usr/bin/python`.
  - Always use: `#!/data/data/com.termux/files/usr/bin/bash` or portable `#!/usr/bin/env bash`.
  - Shell launchers must resolve prefix dynamically:
    ```bash
    PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
    HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
    ```
- **Temporary directories (`/tmp`)**: Android `/tmp` is read-only or nonexistent.
  - Always use `$TMPDIR` or `$PREFIX/tmp`.
  - If a subprocess requires isolation, create scratch spaces under `$HOME/.agents/tmp-...` or `$TMPDIR/...`.

### B. Bionic libc vs glibc Linker (`patchelf` & `glibc-runner`)
- Android uses **Bionic libc**, not GNU C Library (`glibc`).
- Precompiled x86_64 or aarch64 Linux ELF binaries (e.g. OpenCode, Antigravity CLI, Freebuff core binary) fail to run directly on Bionic with errors like:
  ```text
  /system/bin/linker64: No such file or directory
  ```
- **The glibc Runtime Pattern**:
  1. Termux provides a glibc package (`glibc-runner` / `patchelf`).
  2. The dynamic linker is `/data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1`.
  3. Patch the interpreter or run through the loader:
     ```bash
     patchelf --set-interpreter "$PREFIX/glibc/lib/ld-linux-aarch64.so.1" \
              --set-rpath "$PREFIX/glibc/lib:$PREFIX/glibc/usr/lib" \
              "$BINARY_PATH"
     ```
  4. Or wrap with a launcher script invoking `glibc-runner "$BINARY_PATH" "$@"`.

### C. Android Memory, zRAM, & OOM Killer Defense
- Android's Low Memory Killer (LMK / OOM Killer) aggressively terminates background processes exceeding memory limits.
- **Rules for Termux tools**:
  - Prefer streaming, generators, or sqlite disk-backed storage over large in-memory buffers.
  - Enable SQLite WAL mode (`PRAGMA journal_mode=WAL;`) with periodic `VACUUM`.
  - For long-running daemons (e.g. OpenCode web server), monitor memory and restart or flush caches when heap exceeds 250MB.

### D. TUI & Non-Interactive Automation Safety
- Coding agents (Antigravity agy, OpenCode, CI scripts) run commands with redirected stdin (pipes, `/dev/null`).
- Interactive prompts (`read -r -p`, `input()`) **must always detect non-interactive mode**:
  ```bash
  if [ ! -t 0 ]; then
      # Non-interactive mode: use defaults or break, never hang
      return 0
  fi
  read -r -p "Pilihan Anda: " choice
  ```

### E. File Security & Privileges
- Termux is single-user per Android application UID (`u0_aXXX`).
- Secrets (API keys, OAuth tokens) must be stored with restricted permissions:
  ```bash
  chmod 600 "$AUTH_FILE"
  chmod 700 "$SECRET_DIR"
  ```

---

## 2. Blueprint: Creating a New Termux Project

When building a new project for Termux, follow this modular, battle-tested layout:

```text
my-termux-tool/
├── bin/
│   ├── my-tool-launcher.sh     # Bash dispatcher & interactive TUI
│   └── helper-engine.py        # Python 3 logic engine (JSON/SQLite/HTTP)
├── lib/                        # Shared libraries or runtime wrappers
├── tests/
│   └── test_main.sh            # Automated assertion test suite
├── my-tool.sh                  # Root executable / symlink target
├── install.sh                  # One-liner installer (curl | bash)
├── update.sh                   # Upstream git / package updater
├── build-deb.sh                # Optional: Debian (.deb) package generator
└── README.md                   # Complete documentation & quickstart
```

### Standard Component Implementations

#### 1. The One-Liner Installer (`install.sh`)
Must support both interactive menu and non-interactive argument flags:
```bash
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

REPO_URL="https://github.com/username/my-termux-tool.git"
INSTALL_DIR="$HOME/my-termux-tool"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

# Ensure prerequisites
for pkg in git curl python nodejs; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
        pkg install -y "$pkg"
    fi
done

# Clone or update
if [ ! -d "$INSTALL_DIR/.git" ]; then
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
else
    git -C "$INSTALL_DIR" pull --ff-only
fi

# Register symlink in $PREFIX/bin
ln -sf "$INSTALL_DIR/bin/my-tool-launcher.sh" "$PREFIX/bin/mytool"
chmod +x "$PREFIX/bin/mytool"
```

#### 2. The Upstream Update Checker (`update.sh`)
Checks GitHub API or npm registry and compares local git commit/version:
```bash
#!/data/data/com.termux/files/usr/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

git fetch origin main --quiet
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" != "$REMOTE" ]; then
    echo "Pembaruan tersedia! Mengunduh versi terbaru..."
    git pull origin main
    echo "Sukses diperbarui."
else
    echo "Aplikasi sudah dalam versi terbaru."
fi
```

#### 3. Automated Test Suite (`tests/test_main.sh`)
```bash
#!/data/data/com.termux/files/usr/bin/bash
set -e
PASSED=0; FAILED=0
assert_output_contains() {
    local name="$1"; local exp="$2"; shift 2
    local out; out=$("$@") || true
    if [[ "$out" == *"$exp"* ]]; then
        echo -e "  \033[32m[PASS]\033[0m $name"
        PASSED=$((PASSED + 1))
    else
        echo -e "  \033[31m[FAIL]\033[0m $name (Expected '$exp')"
        FAILED=$((FAILED + 1))
    fi
}
# Run tests...
```

---

## 3. Maintenance Guides for the 3 Existing Projects

### A. `freebuff-termux` (`~/freebuff-termux`)
- **Role**: Android Termux client & glibc runtime adapter for Freebuff AI CLI.
- **Key Files**:
  - `bin/freebuff.js`: Main Node.js launcher, update manager, and doctor diagnostics.
  - `install.sh`: One-liner installer and repair runner.
  - `lib/`: Glibc loader wrappers and process broker fix.
- **Update Workflow**:
  ```bash
  cd ~/freebuff-termux
  node bin/freebuff.js update
  node bin/freebuff.js doctor --fix
  ```
- **Common Issue: Terminal Command Broker Error**:
  - *Symptom*: `ld-linux-aarch64.so.1: unrecognized option '--terminal-command-broker'`.
  - *Fix*: Ensure the Bionic launcher spawns the binary via helper rather than invoking the glibc loader as `process.execPath`.

### B. `openclaude-termux` (`~/openclaude-termux`)
- **Role**: Hot-patching `@twigpine/openclaude` to fix stream termination bugs on OpenAI-compatible gateways.
- **Key Files**:
  - `patch-openclaude.mjs`: Node.js AST/regex patcher modifying `dist/cli.mjs` and `dist/sdk.mjs`.
  - `install.sh`: Automatic updater and patch applicator.
  - `test/`: Verification harness ensuring patches prevent truncated tool execution.
- **Update Workflow**:
  ```bash
  cd ~/openclaude-termux
  git pull origin main
  bash install.sh
  # Verifikasi patch berhasil terpasang:
  node patch-openclaude.mjs
  ```
- **Patch Rule**:
  - Intercept `finish_reason: "error"`: immediately abort and throw provider error before incomplete arguments are normalized.
  - Intercept `finish_reason: "length"`: reject incomplete JSON buffers before tool execution.

### C. `termux-ai-tools` (`~/termux-ai-tools`)
- **Role**: Central command orchestrator for OpenCode v1, v2, Antigravity CLI (agy), sessions, memory brain, skills, personas, and provider wizards.
- **Key Files**:
  - `bin/ai-launcher.sh`: Global CLI dispatcher (`ai`).
  - `bin/config-helper.sh`: Interactive API key & provider wizard (`config.sh` / `aiconfig`).
  - `bin/skill-manager.sh`: Agent Skills manager (`skill.sh` / `aiskill`).
  - `bin/agent-manager.sh`: AI Persona manager (`agent.sh` / `aiagent`).
  - `bin/session-manager.sh` & `memory-manager.sh`: Conversation database, FTS5 brain, SQLite vacuum.
  - `bin/doctor.sh`: 18-point system diagnostics.
- **Update & Verification Workflow**:
  ```bash
  cd ~/termux-ai-tools
  git pull origin main
  bash tests/test_config.sh
  bash tests/test_agent.sh
  bash tests/test_skill.sh
  ./doctor.sh
  ```

---

## 4. Cross-Platform Global AI Agent Synchronization (AGY & OpenCode)

To ensure that any new skill or subagent works seamlessly across both **Antigravity CLI (agy)** and **OpenCode (v1 & v2)**, adhere to these exact synchronization locations:

### A. Agent Skills
Agent Skills follow the open `SKILL.md` format (YAML frontmatter + Markdown instructions).
- **Universal Storage (Read by AGY & OpenCode)**:
  `~/.agents/skills/<skill-name>/SKILL.md`
- **Antigravity CLI Dedicated Storage**:
  `~/.gemini/skills/<skill-name>/SKILL.md`
- **OpenCode Dedicated Storage**:
  `~/.config/opencode/skills/<skill-name>/SKILL.md`
- **Rule**: Always place primary skills in `~/.agents/skills/`. To guarantee zero latency in Antigravity, symlink or sync to `~/.gemini/skills/`.

### B. AI Personas / Subagents
Subagents configure specialized system prompts, capabilities, and tool access.
- **Antigravity CLI (agy) Storage**:
  `~/.gemini/config/agents/<agent-name>/agent.md`
  Format:
  ```markdown
  ---
  name: <agent-name>
  description: "<Clear, actionable description of role and trigger conditions>"
  mainAgent: true
  tools:
    - read_file
    - write_file
    - edit_file
    - run_command
    - manage_task
    - send_message
    - schedule
    - invoke_subagent
    - define_subagent
    - manage_subagents
    - search_web
    - ask_question
  ---

  # System Prompt & Instructions ...
  ```
- **OpenCode Storage**:
  `~/.config/opencode/agents/<agent-name>.md`
  Format: Same YAML frontmatter and body, stored as a single flat file.
- **Sync Command**: Use the bundled helper script:
  ```bash
  ~/.agents/skills/termux-app-architect/scripts/sync-agent-global.sh <agent-name>
  ```

---

## 5. Automated Automation Scripts

This skill bundles two ready-to-run automation scripts:

1. **`scripts/scaffold-termux-project.sh <project-name> [type]`**:
   Scaffolds a complete, ready-to-run Termux project repository with `bin/`, `lib/`, `tests/`, `install.sh`, `update.sh`, and `README.md`.
   - Types: `bash-python` (default), `nodejs`, or `patcher`.

2. **`scripts/sync-agent-global.sh <agent-name>`**:
   Instantly mirrors agent definitions between `~/.gemini/config/agents/` and `~/.config/opencode/agents/` and registers skills into `~/.agents/skills/`.
